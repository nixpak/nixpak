{ buildGoModule, stdenvNoCC }:

let
  buildGoModuleNoCC = buildGoModule.override { stdenv = stdenvNoCC; };
in

buildGoModuleNoCC {
  pname = "nixpak-launcher";
  version = "3.1.0";
  src = ./.;
  vendorHash = "sha256-eKvO0w/7rIY4pURRka6pzZ3kx1VBTxUZxIyT7Fb9WQ8=";
}
