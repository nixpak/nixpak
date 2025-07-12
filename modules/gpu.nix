{ config, lib, pkgs, ... }:
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

        * bundle: Bundles a driver package with the application.
      '';
      type = types.enum [ "raw" "nixos" "bundle" ];
      default = "nixos";
    };
    bundlePackage = mkOption {
      description = "Driver package to use when bundling GPU drivers.";
      type = types.package;
      default = pkgs.mesa;
    };
  };
  config.bubblewrap = mkIf config.gpu.enable rec {
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
    bundle = merge raw {
      bind.ro = [
        [ "${config.gpu.bundlePackage}" "/run/opengl-driver" ]
      ];
    };
  }.${config.gpu.provider};
}
