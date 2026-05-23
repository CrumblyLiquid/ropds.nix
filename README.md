# ropds.nix

Package definition and a NixOS module
for the [Rust OPDS Server](https://github.com/dshein-alt/ropds).

## Installation

Add `ropds` as an input to your system flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ropds.url = "github:CrumblyLiquid/ropds.nix";
  };

  outputs = { nixpkgs, ropds, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ropds.nixosModules.ropds
        ./configuration.nix
      ];
    };
  };
}
```

## Usage

A minimal configuration in your `configuration.nix`:

```nix
{
  services.ropds = {
    enable = true;
    baseUrl = "https://opds.example.com";
  };
}
```

This starts ropds on `127.0.0.1:8080`
with the library at `/var/lib/ropds/books`
and an SQLite database at `/var/lib/ropds/ropds.db`.

Reference the `module.nix` for the
rest of the available options.
