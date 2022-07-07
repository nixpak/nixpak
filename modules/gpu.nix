{ config, lib, ... }:
with lib;

let
  merge = a: b: mkMerge [ a b ];
in
{
  options.gpu = {
    enable = mkEnableOption "GPU support";
    provider = mkOption {
      description = ''
        GPU access provider. Supports the following providers:
        
        * raw: Simply mounts all the things required to access GPU devices in /dev/dri. No userspace drivers.
        
        * nixos: Provides GPU drivers by mounting the host's /run/opengl-driver. Ideal for NixOS hosts.
      '';
      type = types.enum [ "raw" "nixos" ];
      default = "nixos";
    };
  };
  config.bubblewrap = rec {
    raw = {
      bind.ro = [
        "/sys/dev/char"
        "/sys/devices/pci0000:00"
      ];
      bind.dev = [
        "/dev/dri"
      ];
    };
    nixos = merge raw {
      bind.ro = [
        "/run/opengl-driver"
      ];
    };
  }.${config.gpu.provider};
}
