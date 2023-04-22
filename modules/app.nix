{ config, lib, ... }:
with lib;

{
  imports = [
    {
      options.app = {
        package = mkOption {
          description = "The app package.";
          type = types.package;
        };

        extraEntrypoints = mkOption {
          description = "Additional entrypoints, such as GNOME search providers.";
          example = [ "/libexec/lollypop-sp" ];
          type = with types; listOf str;
          default = [];
        };
      };
    }
    {
      options.app.binPath = mkOption {
        description = "The app's executable within the package. May need to be set manually if automatic detection fails.";
        type = types.str;
        default = removePrefix "${config.app.package}/" (getExe config.app.package);
      };
    }
  ];
}
