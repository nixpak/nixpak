{ config, lib, ... }:
with lib;

let
  cfg = config.security.nixpak;
in

{
  options.security.nixpak = {
    enable = mkEnableOption "NixPak application sandboxing";

    defaults = mkOption {
      description = "Configuration module to include in all applications.";
      type = types.deferredModule;
      default = {};
    };

    apps = mkOption {
      description = "NixPak apps.";
      type = types.attrsOf (types.submodule {
        options = {
          configuration = mkOption {
            description = "Configuration module for this application.";
            type = types.deferredModule;
            default = {};
          };

          output = mkOption {
            description = "The output of mkNixPak.";
            type = types.raw;
            internal = true;
            readOnly = true;
          };
        };
      });
      default = {};
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = mapAttrsToList (_: app: app.output.config.env) cfg.apps;
  };
}
