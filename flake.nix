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
        version = "1.5.9";

        srcs = {
          x86_64-linux = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_linux_amd64.tar.gz";
            hash = "sha256-Rn56/yU6zKiD76CAQlrHe1+6e/ghS/Pj5Ll9WU1SSRw=";
          };
          aarch64-linux = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_linux_arm64.tar.gz";
            hash = "sha256-LIjiNSD2B43gcdg07Eyf3ACjK6CdrA9uwxJNSBSPuwQ=";
          };
          x86_64-darwin = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_darwin_amd64.tar.gz";
            hash = "sha256-hTxbuM+B7QJHFCCxRJbePGtWKiOliE36CFMUWtf1DbY=";
          };
          aarch64-darwin = {
            url = "https://github.com/skyhook-io/radar/releases/download/v${version}/radar_v${version}_darwin_arm64.tar.gz";
            hash = "sha256-j2f8sMq68CKnqjOpBx2rtndsHEyACeBULevZSBEckyo=";
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
