{ buildGoModule }:

buildGoModule {
  pname = "nixpak-launcher";
  version = "2.0.0";
  src = ./.;
  vendorHash = "sha256-qIdz2WT+Z7zLCNvW7ddeKFw0APPF35BnJaG5Biz8G18=";
}
