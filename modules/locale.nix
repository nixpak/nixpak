{ config, lib, pkgs, ... }:

let
  cfg = config.locale;
in

with lib;

{
  options.locale = {
    enable = mkEnableOption "glibc locale support";
    package = mkOption {
      description = "Locale package.";
      type = types.package;
      default = pkgs.glibcLocales.override {
        allLocales = true;
      };
    };
  };

  config = mkIf cfg.enable {
    bubblewrap.env.LOCALE_ARCHIVE = "${cfg.package}/lib/locale/locale-archive";
  };
}
