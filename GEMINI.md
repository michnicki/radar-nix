# Project Overview: radar-nix

A Nix flake for [radar](https://github.com/skyhook-io/radar), a modern Kubernetes visibility tool.

Currently, this flake is configured as a **binary fetcher** for version **1.5.9**. It downloads pre-built upstream releases for Linux and Darwin (x86_64 and aarch64).

## Building and Running

### Commands
- **Build the package:** `nix build` (Resulting binary at `./result/bin/radar`)
- **Run directly:** `nix run`
- **Development shell:** `nix develop` (Provides `go`, `node`, `make`)

### Usage with Kubernetes
```bash
./result/bin/radar --kubeconfig ~/.kube/config
```

## Project Structure
- `flake.nix`: Defines the package and development shell.
- `flake.lock`: Version lock for Nix inputs.
- `scripts/update-radar.sh`: A shell script (gitignored) that automates version bumps by fetching latest release tags and prefetching hashes for all supported platforms.

## Development Conventions

### Version Bumps
Use the provided script:
```bash
./scripts/update-radar.sh
```
The script will detect the latest version, update `flake.nix`, and create a local commit.

### Maintenance
- Supported platforms: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.
- The `README.md` should be kept in sync with the current version and implementation.
