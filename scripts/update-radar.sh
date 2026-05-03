#!/usr/bin/env bash
# Bumps radar-nix to the latest upstream release.
# Usage: ./scripts/update-radar.sh [--dry-run]
#
# Requires on PATH: git, curl, jq, nix, npm, python3, sed, grep
set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[dry-run] Will skip git push"
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

extract_got_hash() {
    grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' "$1" | tail -1
}

# ── Pre-flight ────────────────────────────────────────────────────────────────

for tool in git curl jq nix npm python3 sed grep; do
    command -v "$tool" > /dev/null 2>&1 || die "Required tool not found: $tool"
done

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" ]] \
    || die "Not on main branch (currently on '$BRANCH'). Switch to main first."
git diff --quiet && git diff --cached --quiet \
    || die "Working tree has uncommitted changes. Commit or stash first."
git remote get-url origin > /dev/null 2>&1 \
    || die "No 'origin' remote configured."

# ── Resolve upstream radar source path ───────────────────────────────────────

RADAR_SRC_DIR=$(grep -oP 'url = "path:\K[^"]+' flake.nix | head -1)
[[ -d "$RADAR_SRC_DIR" ]] \
    || die "Radar source directory not found: $RADAR_SRC_DIR (check the src.url in flake.nix)"

# ── Detect latest release ─────────────────────────────────────────────────────

echo "Fetching latest radar release from GitHub..."
LATEST_TAG=$(curl -fsSL \
    "https://api.github.com/repos/skyhook-io/radar/releases/latest" \
    | jq -r '.tag_name')
[[ "$LATEST_TAG" == v* ]] \
    || die "Unexpected tag format from GitHub API: '$LATEST_TAG'"
NEW_VERSION="${LATEST_TAG#v}"

CURRENT_VERSION=$(grep -oP 'version = "\K[0-9.]+' flake.nix | head -1)
echo "Current: v$CURRENT_VERSION  →  Latest: v$NEW_VERSION"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
    echo "Already at v$NEW_VERSION. Nothing to do."
    exit 0
fi

# ── Update upstream source ────────────────────────────────────────────────────

echo "Checking out v$NEW_VERSION in $RADAR_SRC_DIR..."
git -C "$RADAR_SRC_DIR" fetch --tags
git -C "$RADAR_SRC_DIR" checkout "v$NEW_VERSION"

# ── Patch package-lock.json ───────────────────────────────────────────────────
# Some packages can end up in the lockfile without resolved/integrity fields
# (e.g. installed from a local npm cache before registry metadata was written).
# npm ci in the Nix sandbox fails on these with ENOTCACHED. Fix them up now.

LOCKFILE="$RADAR_SRC_DIR/package-lock.json"

echo "Checking $LOCKFILE for missing resolved/integrity fields..."
MISSING=$(python3 - "$LOCKFILE" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
local_pkgs = {'', 'web', 'packages/k8s-ui'}
missing = [
    (k, data['packages'][k].get('version', '?'))
    for k in data['packages']
    if not data['packages'][k].get('resolved')
    and not data['packages'][k].get('link')
    and k not in local_pkgs
]
for k, v in missing:
    print(f"{k}\t{v}")
PYEOF
)

if [[ -n "$MISSING" ]]; then
    echo "Found packages missing resolved/integrity — fetching from npm registry:"
    while IFS=$'\t' read -r pkg_path version; do
        # Extract bare package name from the path (strip leading node_modules/ etc.)
        pkg_name=$(echo "$pkg_path" | sed 's|.*/node_modules/||')
        echo "  Patching $pkg_name@$version"

        tarball=$(npm view "${pkg_name}@${version}" dist.tarball 2>/dev/null) \
            || die "Could not fetch dist.tarball for $pkg_name@$version"
        integrity=$(npm view "${pkg_name}@${version}" dist.integrity 2>/dev/null) \
            || die "Could not fetch dist.integrity for $pkg_name@$version"

        python3 - "$LOCKFILE" "$pkg_path" "$tarball" "$integrity" <<'PYEOF'
import json, sys
lockfile, pkg_path, tarball, integrity = sys.argv[1:]
with open(lockfile) as f:
    data = json.load(f)
data['packages'][pkg_path]['resolved'] = tarball
data['packages'][pkg_path]['integrity'] = integrity
with open(lockfile, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
    done <<< "$MISSING"
    echo "  Lockfile patched."
else
    echo "  All packages have resolved/integrity fields. No patch needed."
fi

# ── Update version in flake.nix ───────────────────────────────────────────────

echo "Bumping version to $NEW_VERSION..."
sed -i "s|version = \"$CURRENT_VERSION\";|version = \"$NEW_VERSION\";|" flake.nix

# ── Step 1: re-hash the source input ─────────────────────────────────────────

echo "Step 1/3: updating src input hash..."
nix flake update src

# ── Step 2: compute npmDepsHash ───────────────────────────────────────────────

echo "Step 2/3: computing npmDepsHash..."
NEW_NPM_HASH=$(nix run nixpkgs#prefetch-npm-deps -- "$LOCKFILE" 2>/dev/null)
[[ -n "$NEW_NPM_HASH" ]] \
    || die "prefetch-npm-deps returned empty output"
echo "  npmDepsHash: $NEW_NPM_HASH"

CURRENT_NPM_HASH=$(grep -oP 'npmDepsHash = "\Ksha256-[A-Za-z0-9+/=]+' flake.nix | head -1)
sed -i "s|npmDepsHash = \"$CURRENT_NPM_HASH\";|npmDepsHash = \"$NEW_NPM_HASH\";|" flake.nix

# ── Step 3: compute vendorHash ────────────────────────────────────────────────

LOG=$(mktemp /tmp/radar-update.XXXXXX.log)

echo "Step 3/3: computing vendorHash (downloads Go modules, may take a few minutes)..."
CURRENT_VENDOR_HASH=$(grep -oP 'vendorHash = "\Ksha256-[A-Za-z0-9+/=]+' flake.nix | head -1)
sed -i "s|vendorHash = \"$CURRENT_VENDOR_HASH\";|vendorHash = \"$FAKE_HASH\";|" flake.nix

nix build --no-link 2>&1 | tee "$LOG" || true

NEW_VENDOR_HASH=$(extract_got_hash "$LOG")
[[ -n "$NEW_VENDOR_HASH" ]] \
    || die "Could not extract vendorHash from build output. Log: $LOG"
echo "  vendorHash: $NEW_VENDOR_HASH"

sed -i "s|vendorHash = \"$FAKE_HASH\";|vendorHash = \"$NEW_VENDOR_HASH\";|" flake.nix

# ── Final verification build ──────────────────────────────────────────────────

echo "Final verification build..."
if ! nix build; then
    cat >&2 <<EOF

ERROR: Final build failed — likely a non-routine bump (build system changes,
       new embed paths, renamed binary, etc.).
       Compare upstream changes:
         https://github.com/skyhook-io/radar/compare/v$CURRENT_VERSION...v$NEW_VERSION
       Working tree is intentionally left dirty. Finish the bump manually.
EOF
    exit 1
fi

# ── Update README + commit ────────────────────────────────────────────────────

sed -i "s/version \*\*[0-9.]\+\*\*/version **$NEW_VERSION**/" README.md

echo "Committing..."
git add flake.nix flake.lock README.md "$LOCKFILE"
git commit -m "Update to radar v$NEW_VERSION"

if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] Skipping git push. Commit is local only."
else
    echo "Pushing to origin/main..."
    git push origin main
fi

echo ""
echo "Done. radar v$NEW_VERSION"
echo "  npmDepsHash:  $NEW_NPM_HASH"
echo "  vendorHash:   $NEW_VENDOR_HASH"
