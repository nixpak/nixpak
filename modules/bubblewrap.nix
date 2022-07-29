{ lib, pkgs, ... }:
with lib;
let
  mkMountToggle = desc: mkOption {
    default = true;
    type = types.bool;
    description = "Whether to mount ${desc}.";
  };
  
  envPathType = mkOptionType {
    name = "path specifier";
    check = x: strings.isCoercibleToString x && builtins.elem (builtins.substring 0 1 (toString x)) [ "/" "$" ];
  };

  pairOf = elemType: with types; let
    list = nonEmptyListOf elemType;
    checked = addCheck list (l: length l == 2);
  in checked // {
    description = "pair of ${elemType.description}";
  };

  bindType = with types; listOf (oneOf [
    (pairOf envPathType)
    envPathType
  ]);
in {
  options.bubblewrap = {
    network = mkEnableOption "network access in the sandbox" // { default = true; };

    bind.rw = mkOption {
      description = "Read-write paths to bind-mount into the sandbox.";
      type = bindType;
      default = [];
    };

    bind.ro = mkOption {
      description = "Read-only paths to bind-mount into the sandbox.";
      type = bindType;
      default = [];
    };

    bind.dev = mkOption {
      description = "Devices to bind-mount into the sandbox.";
      type = bindType;
      default = [];
    };

    package = mkOption {
      description = "Bubblewrap package to use.";
      type = types.package;
      default = pkgs.bubblewrap;
    };

    apivfs = {
      proc = mkMountToggle "the /proc API VFS";
      dev = mkMountToggle "the /dev API VFS";
    };

    env = mkOption {
      description = "Environment variables to set.";
      type = with types; attrsOf (nullOr str);
      default = {};
    };
  };
}