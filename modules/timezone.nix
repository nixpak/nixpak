{ config, lib, pkgs, ... }:

let
  cfg = config.timeZone;
in

with lib;

{
  options.timeZone = {
    enable = mkEnableOption "timezone configuration";
    provider = mkOption {
      description = ''
        Time zone provider. Available providers:

        * host: will simply mount /etc/localtime into the sandbox.

        * bundle: will use a configured time zone from tzdata.
      '';
      type = types.enum [ "host" "bundle" ];
      default = "host";
    };
    package = mkOption {
      description = "tzdata package to use for bundled time zones.";
      type = types.package;
      default = pkgs.tzdata;
    };
    zone = mkOption {
      description = "Time zone to use.";
      type = types.str;
      default = "UTC";
      example = "Europe/Zurich";
    };
  };

  config.bubblewrap.bind.ro = mkIf cfg.enable {
    host = [ "/etc/localtime" ];

    bundle = [
      [
        "${cfg.package}/share/zoneinfo/${cfg.zone}"
        "/etc/localtime"
      ]
    ];
  }.${cfg.provider};
}
