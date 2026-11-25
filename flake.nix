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
        version = "1.21.4";

        srcs = {
          x86_64-linux = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_linux_amd64.tar.gz";
            hash = "sha256-71us7KNmb1Xyx5V1tJo52rkbhemvV/YsMpqAFLwVnN0=";
          };
          aarch64-linux = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_linux_arm64.tar.gz";
            hash = "sha256-uQO5GtDnRrmg0K7pdBZAHOL1Rp6lU0OfDhbttBbatQQ=";
          };
          x86_64-darwin = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_darwin_amd64.tar.gz";
            hash = "sha256-2yB9tU58/0PVwlg2SQPqfniZIMwL3RIKsLeDooC96OY=";
          };
          aarch64-darwin = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_darwin_arm64.tar.gz";
            hash = "sha256-FLgY5CafeWV/RwEvKyFGqcP1k/qbx2dGSleSRMXBqwg=";
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
