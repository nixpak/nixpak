{ lib, self, ... }:
{
  perSystem = { pkgs, system, ... }: {
    config.builders = {
      mkNixPakConfiguration = args: let
        mkNixPak = self.lib.nixpak {
          inherit lib;
          inherit pkgs;
        };
      in mkNixPak args;
    };
  };
}
