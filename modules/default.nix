{ lib, pkgs }:
{ config, specialArgs ? {} }:

lib.evalModules {
  inherit specialArgs;
  modules = [
    config

    { _module.args = { inherit pkgs; }; }
    
    ./app.nix
    ./bubblewrap.nix
    ./dbus.nix
    ./etc.nix
    ./gpu.nix
    ./launch.nix
    ./locale.nix

    ./flatpak-shim/flatpak-desktop-file.nix
    ./flatpak-shim/flatpak-info.nix
    ./flatpak-shim/flatpak-session-helper.nix

    ./gui/fonts.nix

    ./lib/sloth.nix
  ];
}
