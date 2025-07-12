{ config, lib, pkgs, ... }:

with lib;

{
  options.pasta = {
    enable = mkEnableOption "Pasta networking";
    package = mkOption {
      description = "Pasta package to use.";
      type = types.package;
      default = pkgs.passt.overrideAttrs (old: {
        patches = (old.patches or []) ++ [
          # This patch let's pasta get the user namespace from the mount namespace.
          # This is necessary, since bubblewrap sometimes (e.g. when the --dev option
          # is used) uses two layers of user namespaces and pasta sometimes (since
          # also a race-condition is involved; see
          # https://github.com/containers/bubblewrap/issues/634) fails to detect the
          # correct user namespace.
          ./patches/passt-fix-user-namespace-detection.patch
        ];
      });
    };
    mode = mkOption {
      type = types.enum [ "transparent" "isolate" ];
      description = "Operation mode of pasta.";
      default = "isolate";
    };
    args = mkOption {
      type = types.listOf types.str;
      description = "Arguments (networking options) to pasta.";
      default = [];
    };
  };
  config.pasta.args = flatten [
    "--config-net"
    # Disable services not needed due to --config-net
    "--no-dhcp"
    "--no-dhcpv6"
    "--no-ndp"
    "--no-ra"
    # Mapping the gateway address to host also does not make sense in transparent mode, because this would prevent connections to the original gateway copied from host
    "--no-map-gw"
    (optionals (config.pasta.mode == "isolate") [
      # Disable port forwarding to host
      "--tcp-ns" "none"
      "--udp-ns" "none"
      # Disable port forwarding to sandbox
      "--tcp-ports" "none"
      "--udp-ports" "none"
      # Use common generic addresses to avoid fingerprinting
      "--ns-ifname" "eth0"
      "--address" "192.168.1.100"
      "--netmask" "255.255.255.0"
      "--gateway" "192.168.1.1"
      "--mac-addr" "52:54:00:12:34:56"
      "--dns-forward" "192.168.1.1"
      "--search" "none"
    ])
  ];
  config.bubblewrap = let
    pastaEnable = config.bubblewrap.network && config.pasta.enable;
    resolvConfFile = pkgs.writeTextDir "etc/resolv.conf" ''
      nameserver 192.168.1.1
    '';
    hostsFile = pkgs.writeTextDir "etc/hosts" ''
      127.0.0.1 localhost
      ::1 localhost
      192.168.1.100 localhost
    '';
  in mkMerge [
    (mkIf (pastaEnable && config.pasta.mode == "transparent") {
      bind.ro = [
        "/etc/resolv.conf"
        "/etc/hosts"
      ];
    })
    (mkIf (pastaEnable && config.pasta.mode == "isolate") {
      extraStorePaths = [ resolvConfFile hostsFile ];
      bind.ro = [
        [ "${resolvConfFile}/etc/resolv.conf" "/etc/resolv.conf" ]
        [ "${hostsFile}/etc/hosts" "/etc/hosts" ]
      ];
    })
  ];
}
