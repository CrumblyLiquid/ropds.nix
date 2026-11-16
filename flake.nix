{
  description = "Ropds package definition and its corresponding NixOS module";

  nixConfig = {
    extra-substituters = [ "https://crumblyliquid.cachix.org" ];
    extra-trusted-public-keys = [
      "crumblyliquid.cachix.org-1:pYHod577Itv38u+CcfnJipur0L8yBtD76oVagRgND5A="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crate2nix = {
      url = "github:nix-community/crate2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crate2nix,
    }:
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

          version = "0.14.0";

          src = pkgs.fetchFromGitHub {
            owner = "dshein-alt";
            repo = "ropds";
            tag = "v${version}";
            hash = "sha256-xkx8S5tfTEj8FWbS4aAdhrsZnQG+62NvQzM2opfO6SE=";
          };

          cargoNix = crate2nix.tools.${system}.appliedCargoNix {
            name = "ropds";
            inherit src;
          };
        in
        {
          default = pkgs.symlinkJoin {
            pname = "ropds";
            inherit version;
            paths = [ cargoNix.rootCrate.build ];

            passthru = {
              inherit src;
            };

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
