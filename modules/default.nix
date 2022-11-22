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

    ./flatpak-shim/flatpak-info.nix
  ];
}
