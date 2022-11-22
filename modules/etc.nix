{ config, lib, pkgs, ... }:

let
  cfg = config.etc.sslCertificates;
in

with lib;

{
  options = {
    etc.sslCertificates = {
      enable = mkEnableOption "SSL/TLS certificate support";
      path = mkOption {
        description = "SSL/TLS certificate bundle file";
        type = types.path;
        default = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
    };
  };

  config = mkIf cfg.enable {
    bubblewrap.bind.ro = [
      [ cfg.path "/etc/ssl/certs/ca-bundle.crt" ]
      [ cfg.path "/etc/ssl/certs/ca-certificates.crt" ]
    ];
  };
}
