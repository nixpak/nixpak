{
  description = "NixPak - sandboxing for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs: let
    supportedSystems = [
      "x86_64-linux"
      "i686-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
    forSystem = forEachSystem (system: {
      mkNixPak = self.lib.nixpak {
        inherit (nixpkgs) lib;
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };
    });
  in {
    lib.nixpak = import ./modules;

    packages = forEachSystem (system: {
      busybox = (import ./examples/busybox.nix {
        inherit (forSystem.${system}) mkNixPak; 
        inherit (nixpkgs.legacyPackages.${system}) busybox;
      }).config.script;

      useless-curl = (import ./examples/network-isolation-demo.nix {
        inherit (forSystem.${system}) mkNixPak; 
        inherit (nixpkgs.legacyPackages.${system}) curl;
      }).config.script;
    });

    bundlers = forEachSystem (system: {
      nixpak = drv: (import ./examples/bundler.nix {
        inherit drv;
        inherit (forSystem.${system}) mkNixPak; 
      }).config.script;
    });
  };
}
