{ config, lib, ... }:

with lib;

let
  cfg = config.monitor;

  mkMonitorOption = _path: default: mkEnableOption "bind mount for ${_path}" // {
    inherit _path default;
  };
in

rec {
  options.monitor = {
    hostconf = mkMonitorOption "/etc/host.conf" false;
    hosts = mkMonitorOption "/etc/hosts" false;
    resolvconf = mkMonitorOption "/etc/resolv.conf" false;
    localtime = mkMonitorOption "/etc/localtime" true;
    timezone = mkMonitorOption "/etc/timezone" true;
  };

  config.bubblewrap.bind.ro = mapAttrsToList
    (n: v: options.monitor.${n}._path) # Get the option's bind path
    (filterAttrs (n: v: v) cfg); # Only options that are set
}
