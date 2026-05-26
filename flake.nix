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
            version = "v0.11.4";

            src = pkgs.fetchFromGitHub {
              owner = "dshein-alt";
              repo = "ropds";
              rev = version;
              hash = "sha256-Kb6BGbABpo+pW4hFtlPjl/crGKDiHvng/g/iBvHWwbc=";
            };

            cargoHash = "sha256-UGThSlf+XW7ygGHSScmvXbYkQa55TY5B0FZQUJDpMpM=";

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
