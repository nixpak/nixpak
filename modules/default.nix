{ lib, pkgs }:
{ config, specialArgs ? {} }:

lib.evalModules {
  inherit specialArgs;
  modules = [
    config

    { _module.args = { inherit pkgs; }; }

    ./app.nix
    ./bubblewrap.nix
    ./pasta.nix
    ./dbus.nix
    ./wayland-proxy.nix
    ./etc.nix
    ./gpu.nix
    ./launch.nix
    ./locale.nix
    ./timezone.nix

    ./flatpak-shim/flatpak-desktop-file.nix
    ./flatpak-shim/flatpak-info.nix

    ./gui/fonts.nix

    ./lib/sloth.nix
  ];
}
