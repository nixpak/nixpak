{ buildGoModule }:

buildGoModule {
  pname = "nixpak-launcher";
  version = "2.0.0";
  src = ./.;
  vendorHash = "sha256-WUTGAYigUjuZLHO1YpVhFSWpvULDZfGMfOXZQqVYAfs=";
}
