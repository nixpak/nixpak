{ self, ... }:

{
  flake.nixosModules.default = ({ config, lib, pkgs, ... }@nixos: let
    mkNixPak = self.lib.nixpak {
      inherit lib pkgs;
    };
  in {
    imports = [
      ./nixpak-nixos-module.nix
    ];
    options.security.nixpak.apps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, name, ... }: {
        output = mkNixPak {
          config.imports = [
            config.configuration
            nixos.config.security.nixpak.defaults
          ];
          specialArgs = { inherit name; };
        };
      }));
    };
  });
}
