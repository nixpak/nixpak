{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
    nixpakModules.network
  ];
  module = {
    flatpak.appId = "org.gnome.Maps";
  };
}
