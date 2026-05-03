# radar-nix

Nix flake for [radar](https://github.com/skyhook-io/radar) — a modern Kubernetes visibility tool with topology visualization, Helm management, GitOps support, and a built-in MCP server for AI integration.

Packages version **0.2.2** as a single static binary (`radar`) built from source: the React/Vite frontend is compiled with npm and embedded into the Go binary.

## Usage

### Run without installing

```bash
nix run git+ssh://git@codeberg.org/tmichnicki/radar-nix.git -- --help
```

### Build

```bash
nix build git+ssh://git@codeberg.org/tmichnicki/radar-nix.git
./result/bin/radar --kubeconfig ~/.kube/config
```

### Install to your profile

```bash
nix profile install git+ssh://git@codeberg.org/tmichnicki/radar-nix.git
```

### NixOS / nix-darwin flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    radar-nix.url = "git+ssh://git@codeberg.org/tmichnicki/radar-nix.git";
  };

  outputs = { nixpkgs, radar-nix, ... }: {
    nixosConfigurations.mymachine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [{
        environment.systemPackages = [
          radar-nix.packages.x86_64-linux.default
        ];
      }];
    };
  };
}
```

### home-manager

```nix
{ inputs, pkgs, system, ... }: {
  home.packages = [
    inputs.radar-nix.packages.${system}.default
  ];
}
```

## Development shell

Enters a shell with Go, Node.js 20, and make — enough to build radar locally with `make build`.

```bash
nix develop git+ssh://git@codeberg.org/tmichnicki/radar-nix.git
```

## Updating to a new version

Run the update script to handle everything automatically:

```bash
./scripts/update-radar.sh          # update and push
./scripts/update-radar.sh --dry-run  # update locally, skip push
```

The script: checks out the new tag in the local radar source, patches any missing `resolved`/`integrity` fields in `package-lock.json`, recomputes all three hashes in order, runs a final verification build, and commits.

If you need to update manually, the three hashes must be kept in sync in this order:

### 1. Update the source

Change `version` in `flake.nix` to the new release tag (without the `v` prefix), then update the source lock:

```bash
nix flake update src
```

### 2. Update `npmDepsHash`

Radar's frontend deps are locked by the root `package-lock.json`. If it changed, recompute:

```bash
cd /path/to/radar
nix run nixpkgs#prefetch-npm-deps -- package-lock.json
```

Paste the result into `npmDepsHash` in `flake.nix`.

> **Note:** Three packages (`@vitejs/plugin-react`, `@rolldown/pluginutils`, `@types/diff`) were missing `resolved`/`integrity` fields in the lockfile of v0.2.2. If you see `ENOTCACHED` errors during the npm build after updating, check for packages with no `resolved` field:
>
> ```bash
> python3 -c "
> import json
> with open('package-lock.json') as f: d = json.load(f)
> missing = [(k, v.get('version')) for k, v in d['packages'].items()
>            if not v.get('resolved') and not v.get('link') and k not in ('', 'web', 'packages/k8s-ui')]
> [print(k, v) for k, v in missing]
> "
> ```
>
> For any that appear, fetch their metadata with `npm view <pkg>@<version> dist.tarball dist.integrity` and add `resolved`/`integrity` to the lockfile entry, then recompute `npmDepsHash`.

### 3. Update `vendorHash`

Set `vendorHash` to a fake hash, run `nix build`, and copy the correct hash from the error:

```bash
# In flake.nix, set:
#   vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
nix build 2>&1 | grep "got:"
```

Paste the `got:` hash into `vendorHash`.

### 4. Verify

```bash
nix build && ./result/bin/radar --version
```

## Build notes

- **Two-derivation build**: `radarFrontend` (npm) is built first; the Go derivation copies its output into `internal/static/dist/` before compiling, so the binary has the frontend embedded.
- **Multi-module repo**: `pkg/` is a separate Go module replaced via `replace github.com/skyhook-io/radar/pkg => ./pkg` in `go.mod`. Using a proper `vendorHash` (not `null`) is required — `null` skips the vendor derivation and trips on this local replace directive.
- **Binary name**: upstream `go build` outputs `radar`; `go install` names the binary after the directory (`explorer`), so `postInstall` renames it.
- **CGO disabled**: the binary is fully static (`CGO_ENABLED = 0`).

## License

Apache 2.0 — see the [upstream repository](https://github.com/skyhook-io/radar/blob/main/LICENSE).
