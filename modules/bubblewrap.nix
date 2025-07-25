{ config, lib, pkgs, sloth, ... }:
with lib;
let
  mkMountToggle = desc: mkOption {
    default = true;
    type = types.bool;
    description = "Whether to mount ${desc}.";
  };
  
  pairOf = elemType: with types; let
    list = nonEmptyListOf elemType;
    checked = addCheck list (l: length l == 2);
  in checked // {
    description = "pair of ${elemType.description}";
  };

  bindType = with types; listOf (oneOf [
    (pairOf sloth.type)
    sloth.type
  ]);
in {
  options.bubblewrap = {
    network = mkEnableOption "network access in the sandbox" // { default = true; };
    shareIpc = mkEnableOption "host IPC namespace in the sandbox";

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

    tmpfs = mkOption {
      description = "Tmpfs locations.";
      type = types.listOf sloth.type;
      default = [];
    };

    bindEntireStore = mkEnableOption "Bind entire nix store." // { default = true; };

    extraStorePaths = mkOption {
      description = "Extra nix store paths that will be recursively bound.";
      type = types.listOf types.package;
      default = [];
    };

    sockets = {
      wayland = mkMountToggle "the active Wayland socket" // { default = false; };
      pipewire = mkMountToggle "the first PipeWire socket" // { default = false; };
      x11 = mkMountToggle "all X11 sockets" // { default = false; };
      pulse = mkMountToggle "the PulseAudio socket" // { default = false; };
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

    clearEnv = mkOption {
      description = "Unset all environment variables.";
      type = types.bool;
      default = false;
    };

    env = mkOption {
      description = "Environment variables to set.";
      type = with types; attrsOf (nullOr sloth.type);
      default = {};
    };
  };

  config = {
    bubblewrap.bind.ro = let
      mapNetFiles = config.bubblewrap.network && !config.pasta.enable;
      cfg = config.bubblewrap.sockets;
    in
      (optional mapNetFiles "/etc/resolv.conf")
      ++ (optional mapNetFiles "/etc/hosts")
      ++ (optional cfg.wayland (sloth.concat [sloth.runtimeDir "/" (sloth.envOr "WAYLAND_DISPLAY" "wayland-0")]))
      ++ (optional cfg.pipewire (sloth.concat' sloth.runtimeDir "/pipewire-0"))
      ++ (optionals cfg.x11 [
        (sloth.env "XAUTHORITY")
        "/tmp/.X11-unix"
      ])
      ++ (optional cfg.pulse (sloth.concat' sloth.runtimeDir "/pulse"));
  };
}
