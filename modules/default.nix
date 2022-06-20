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
    ./launch.nix
  ];
}
