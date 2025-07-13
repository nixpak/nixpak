{ config, lib, pkgs, ... }:

with lib;

{
  options.waylandProxy = {
    enable = mkEnableOption "Proxied Wayland access";
    package = mkOption {
      description = "Wayland-proxy-virtwl package to use.";
      type = types.package;
      default = pkgs.wayland-proxy-virtwl;
    };
    tag = mkOption {
      type = types.str;
      description = "Tag to prefix to window titles.";
      default = "[${config.app.package.pname or (builtins.parseDrvName config.app.package.name).name}] ";
    };
    args = mkOption {
      type = with types; listOf str;
      description = "Arguments (proxy options) to wayland-proxy-virtwl.";
      default = [];
    };
  };
  config.waylandProxy.args = [
    "--tag=${config.waylandProxy.tag}"
  ];
}
