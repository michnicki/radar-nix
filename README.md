# radar-nix

Nix flake for [radar](https://github.com/skyhook-io/radar) — a modern Kubernetes visibility tool with topology visualization, Helm management, GitOps support, and a built-in MCP server for AI integration.

Packages version **1.5.9** as a static binary (`radar`) fetched from the official upstream releases.

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

Enters a shell with Go, Node.js 20, and make — useful for local experimentation.

```bash
nix develop git+ssh://git@codeberg.org/tmichnicki/radar-nix.git
```

## Updating to a new version

Version bumps are automated via a local script.

```bash
./scripts/update-radar.sh
```

The script fetches the latest release tag from GitHub, prefetches hashes for all supported platforms (`x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`), updates `flake.nix`, and commits the changes.

## License

Apache 2.0 — see the [upstream repository](https://github.com/skyhook-io/radar/blob/main/LICENSE).
