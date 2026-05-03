{
  description = "Radar - Modern Kubernetes visibility tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    src = {
      url = "path:/home/thomas/projects/nix-packages/radar";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "0.2.2";

        radarFrontend = pkgs.buildNpmPackage {
          pname = "radar-frontend";
          inherit version;
          src = src;

          npmDepsHash = "sha256-pf+GLTX+Ezb24sW1VGTt1eePpCZP82r11cy9uWLN9dY=";

          buildPhase = ''
            runHook preBuild
            npm run build --workspace=web
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r web/dist/. $out/
            runHook postInstall
          '';
        };

        radar = pkgs.buildGoModule {
          pname = "radar";
          inherit version src;

          vendorHash = "sha256-teLJgCcHHpNhI2S/rvGYsLlG6fvd7llcoN98k+2+kzg=";

          subPackages = [ "cmd/explorer" ];

          preBuild = ''
            mkdir -p internal/static/dist
            cp -r ${radarFrontend}/. internal/static/dist/
          '';

          ldflags = [
            "-s"
            "-w"
            "-X main.version=${version}"
          ];

          env.CGO_ENABLED = 0;

          postInstall = ''
            mv $out/bin/explorer $out/bin/radar
          '';

          meta = with pkgs.lib; {
            description = "Modern Kubernetes visibility tool";
            homepage = "https://github.com/skyhook-io/radar";
            license = licenses.asl20;
            maintainers = [ ];
            mainProgram = "radar";
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
