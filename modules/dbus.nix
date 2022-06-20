{ config, lib, pkgs, ... }:
with lib;
let
  inherit (types) attrsOf listOf enum str;
in {
  options.dbus = {
    enable = mkEnableOption "D-Bus access" // { default = true; };
    policies = mkOption {
      default = {};
      type = attrsOf (enum [ "see" "talk" "own" ]);
      description = "Policies to apply to the given bus object name.";
    };
    rules.call = mkOption {
      default = {};
      type = attrsOf (listOf str);
      description = "Rules for calls on the given bus object name.";
    };
    rules.broadcast = mkOption {
      default = {};
      type = attrsOf (listOf str);
      description = "Rules for broadcasts on the given bus object name.";
    };
    args = mkOption {
      default = [];
      type = listOf str;
      description = "Arguments (proxy options) to xdg-dbus-proxy.";
    };
  };
  config.dbus.args =
    (mapAttrsToList (n: v: "--${v}=${n}") config.dbus.policies) ++

    (flatten (mapAttrsToList
      (n: v: map (x: "--call=${n}=${x}") v)
        config.dbus.rules.call)
    ) ++

    (flatten (mapAttrsToList
      (n: v: map (x: "--broadcast=${n}=${x}") v)
        config.dbus.rules.broadcast)
    );
}