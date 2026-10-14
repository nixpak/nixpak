{
  config,
  lib,
  ...
}:
with lib;
let
  inherit (types)
    attrsOf
    listOf
    enum
    str
    ;
  makeArgs =
    conf:
    (mapAttrsToList (n: v: "--${v}=${n}") conf.policies)
    ++

      (flatten (mapAttrsToList (n: v: map (x: "--call=${n}=${x}") v) conf.rules.call))
    ++

      (flatten (mapAttrsToList (n: v: map (x: "--broadcast=${n}=${x}") v) conf.rules.broadcast));
  sharedPoliciesOptions = {
    policies = mkOption {
      default = { };
      type = attrsOf (enum [
        "see"
        "talk"
        "own"
      ]);
      description = "Policies to apply to the given bus object name.";
    };
    rules.call = mkOption {
      default = { };
      type = attrsOf (listOf str);
      description = "Rules for calls on the given bus object name.";
    };
    rules.broadcast = mkOption {
      default = { };
      type = attrsOf (listOf str);
      description = "Rules for broadcasts on the given bus object name.";
    };
    args = mkOption {
      default = [ ];
      type = listOf str;
      description = "Arguments (proxy options) to xdg-dbus-proxy.";
    };
  };

in
{
  options = {
    system-dbus = sharedPoliciesOptions // {
      enable = mkEnableOption "System D-Bus access" // {
        default = true;
      };
    };
    dbus = sharedPoliciesOptions // {
      enable = mkEnableOption "D-Bus access" // {
        default = true;
      };
    };
  };
  config = {
    system-dbus.args = makeArgs config.system-dbus;
    dbus.args = makeArgs config.dbus;
  };
}
