{ lib, ... }:
with lib;

{
  options.flatpak.session-helper = {
    enable = mkEnableOption "flatpak-session-helper service";
  };
}
