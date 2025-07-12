{ buildGoModule, stdenvNoCC }:

let
  buildGoModuleNoCC = buildGoModule.override { stdenv = stdenvNoCC; };
in

buildGoModuleNoCC {
  pname = "nixpak-launcher";
  version = "3.1.0";
  src = ./.;
  vendorHash = "sha256-b+OnCivNo2RpfPupdAdfqR2ywDWKcDDru5yDfxw1Tvs=";
}
