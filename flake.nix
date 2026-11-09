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
            version = "0.13.2";

            src = pkgs.fetchFromGitHub {
              owner = "dshein-alt";
              repo = "ropds";
              tag = "v${version}";
              hash = "sha256-T+wc2Gduns1vVrLqIY6gd2nKphC6ZQ6ePGZD3QqMmCo=";
            };

            cargoHash = "sha256-fi9zpUEzRIGVNpvG605S55QA9cz56UuXNM7znZgRNxg=";

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
