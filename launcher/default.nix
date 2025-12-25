{ buildGoModule }:

buildGoModule {
  pname = "nixpak-launcher";
  version = "3.1.0";
  src = ./.;
  vendorHash = "sha256-toln0x1Q9zz/yl3DY4eXnP1bSTO5INe9rBYSPD2ZpK0=";
}
