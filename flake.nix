{
  description = "NixPak - sandboxing for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    hercules-ci-effects = {
      url = "github:hercules-ci/hercules-ci-effects";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  outputs = { self, nixpkgs, flake-parts, ... }@inputs:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.hercules-ci-effects.flakeModule
      ./jobs/update-flake-lock
    ];

    systems = [
      "x86_64-linux"
      "i686-linux"
      "aarch64-linux"
    ];

    flake.lib.nixpak = import ./modules;

    perSystem = { pkgs, system, ... }: let
      mkNixPak = self.lib.nixpak {
        inherit (nixpkgs) lib;
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };
    in {
      packages = {
        busybox = (import ./examples/busybox.nix {
          inherit mkNixPak;
          inherit (pkgs) busybox;
        }).config.script;

        useless-curl = (import ./examples/network-isolation-demo.nix {
          inherit mkNixPak;
          inherit (pkgs) curl;
        }).config.script;

        vim = (import ./examples/multiple-executables.nix {
          inherit mkNixPak;
          inherit (pkgs) vim;
        }).config.env;
      };
    };
  };
}
