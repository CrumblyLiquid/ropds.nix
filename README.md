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

## Binary cache

CI builds are pushed to a [Cachix](https://cachix.org) cache.
To use it, add this to your NixOS configuration:

```nix
{
  nix.settings = {
    extra-substituters = [ "https://crumblyliquid.cachix.org" ];
    extra-trusted-public-keys = [
      "crumblyliquid.cachix.org-1:pYHod577Itv38u+CcfnJipur0L8yBtD76oVagRgND5A="
    ];
  };
}
```

The flake also advertises the cache through `nixConfig`,
which Nix offers to use when you build it directly
(or pass `--accept-flake-config`).

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
