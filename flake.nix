{
  description = "icey-server packaged as a Nix flake";

  inputs =
    let
      trim = s: builtins.replaceStrings ["\n" "\r"] ["" ""] s;
      iceyVersion = trim (builtins.readFile ./ICEY_VERSION);
    in {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      flake-utils.url = "github:numtide/flake-utils";
      icey = {
        url = "github:nilstate/icey/${iceyVersion}";
        flake = false;
      };
    };

  outputs = { self, nixpkgs, flake-utils, icey }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        version = builtins.replaceStrings ["\n" "\r"] ["" ""] (builtins.readFile ./VERSION);
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "icey-server";
          inherit version;
          src = self;

          nativeBuildInputs = with pkgs; [
            cmake
            nodejs
            pkg-config
          ];

          buildInputs = with pkgs; [
            ffmpeg
            openssl
          ];

          buildPhase = ''
            runHook preBuild
            npm --prefix web ci
            npm --prefix web run build
            cmake -S . -B build \
              -DCMAKE_BUILD_TYPE=Release \
              -DICEY_SOURCE_DIR=${icey}
            cmake --build build -j1 --target icey-server
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            cmake --install build --prefix $out --component apps
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Self-hosted source-to-browser server built on icey";
            homepage = "https://0state.com/icey/";
            license = licenses.agpl3Plus;
            platforms = platforms.linux ++ platforms.darwin;
            mainProgram = "icey-server";
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
          exePath = "/bin/icey-server";
        };
      });
}
