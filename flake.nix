{
  description = "Radar - Modern Kubernetes visibility tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "1.13.1";

        srcs = {
          x86_64-linux = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_linux_amd64.tar.gz";
            hash = "sha256-7eNQ7cZpYLdWzNG2t8FLr+oFePwKMAq1Vl8uX8lSxIM=";
          };
          aarch64-linux = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_linux_arm64.tar.gz";
            hash = "sha256-rJZEsL8UEKzPRikO31lV9Jh3z+NrdxHp+oeSYqK35xQ=";
          };
          x86_64-darwin = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_darwin_amd64.tar.gz";
            hash = "sha256-yMY4mcvtOdOnuRmTsEyMm126ekLFN8Fk+qWPBpc7uCg=";
          };
          aarch64-darwin = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_darwin_arm64.tar.gz";
            hash = "sha256-+hbwvrLJZoaJHeTKy0YiPihmiOXNCTmaLjDxBjYjzc4=";
          };
        };

        src = srcs.${system} or (throw "Unsupported system: ${system}");

        radar = pkgs.stdenv.mkDerivation {
          pname = "radar";
          inherit version;

          src = pkgs.fetchurl { inherit (src) url hash; };

          nativeBuildInputs = [ pkgs.gnutar ];

          unpackPhase = ''
            tar -xzf $src
          '';

          installPhase = ''
            mkdir -p $out/bin
            install -m755 kubectl-radar $out/bin/radar
          '';

          meta = with pkgs.lib; {
            description = "Modern Kubernetes visibility tool";
            homepage = "https://github.com/skyhook-io/radar";
            license = licenses.asl20;
            maintainers = [ ];
            mainProgram = "radar";
            platforms = builtins.attrNames srcs;
          };
        };
      in
      {
        packages.default = radar;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            nodejs_20
            gnumake
          ];
        };
      });
}
