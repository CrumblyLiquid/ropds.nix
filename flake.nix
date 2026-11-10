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
          default = pkgs.rustPlatform.buildRustPackage rec {
            pname = "ropds";
            version = "0.14.0";

            src = pkgs.fetchFromGitHub {
              owner = "dshein-alt";
              repo = "ropds";
              tag = "v${version}";
              hash = "sha256-xkx8S5tfTEj8FWbS4aAdhrsZnQG+62NvQzM2opfO6SE=";
            };

            cargoHash = "sha256-oGXFMKD+xy9M/M4Ot3G2Mt7XGfvziOqZy5m9z2tJgBE=";

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
