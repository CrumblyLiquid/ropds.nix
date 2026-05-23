{
  description = "Ropds package definition and its corresponding NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.rustPlatform.buildRustPackage {
            pname = "ropds";
            version = "master";

            src = pkgs.fetchFromGitHub {
              owner = "dshein-alt";
              repo = "ropds";
              rev = "master";
              hash = "sha256-CV3LGc6WtyQReKhtmWV3OskcPMNjWAhGbxGU/0jMnN0=";
            };

            cargoHash = "sha256-tdn4z0CIhrCfrfc8euAC9kh3dHIVGcHKVYcbarX7pZQ=";

            meta = {
              description = "ropds - OPDS server";
              homepage = "https://github.com/dshein-alt/ropds";
              mainProgram = "ropds";
              license = pkgs.lib.licenses.mit;
              maintainers = [ ];
            };
          };
        }
      );

      nixosModules = {
        ropds = import ./module.nix self;
        default = import ./module.nix self;
      };
    };
}
