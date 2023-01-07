{ config, lib, ... }:
with lib;

{
  options.flatpak = {
    desktopFile = mkOption {
      description = "Main .desktop file name. If different from the default, the file will be renamed to \${config.flatpak.appId}.desktop";
      type = types.str;
      default = "${config.flatpak.appId}.desktop";
    };
  };
}
