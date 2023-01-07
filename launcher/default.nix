{ buildGoModule, stdenvNoCC }:

let
  buildGoModuleNoCC = buildGoModule.override { stdenv = stdenvNoCC; };
in

buildGoModuleNoCC {
  pname = "nixpak-launcher";
  version = "1.0.1";
  src = ./.;
  vendorSha256 = null;
}
