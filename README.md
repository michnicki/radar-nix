# radar-nix

Nix flake for [radar](https://github.com/skyhook-io/radar), a modern Kubernetes visibility tool with topology visualization, Helm management, GitOps support, and an MCP server for AI integration.

## Package Summary

| Field | Value |
|---|---|
| Upstream | [skyhook-io/radar](https://github.com/skyhook-io/radar) |
| Packaged version | `1.7.0` |
| Main program | `radar` |
| Supported systems | `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin` |
| Flake outputs | `packages.${system}.default`, `devShells.${system}.default` |

## Requirements

- Nix with flakes enabled.
- A Kubernetes configuration if you want to connect radar to a cluster.

## Usage

### Run without installing

```bash
nix run github:michnicki/radar-nix -- --help
```

### Build

```bash
nix build github:michnicki/radar-nix
./result/bin/radar --kubeconfig ~/.kube/config
```

### Install into a profile

```bash
nix profile install github:michnicki/radar-nix
```

### Use in a NixOS or home-manager module

After adding `inputs.radar-nix.url = "github:michnicki/radar-nix";` to your flake, add the package to your module:

```nix
{ inputs, pkgs, ... }: {
  environment.systemPackages = [
    inputs.radar-nix.packages.${pkgs.system}.default
  ];
}
```

For home-manager, add the same package to `home.packages`.

## Development

Enter the development shell to get Go, Node.js 20, and make:

```bash
nix develop github:michnicki/radar-nix
```

## Updating

Use the update helper from the repository root:

```bash
./scripts/update-radar.sh [--dry-run]
```

The script fetches the latest upstream release, updates the version and platform hashes in `flake.nix`, verifies the build, and commits the bump. With `--dry-run`, it skips pushing.

## License

Radar is licensed under Apache 2.0. See the [upstream license](https://github.com/skyhook-io/radar/blob/main/LICENSE).
