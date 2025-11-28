{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
  ];
  module = {
    flatpak.appId = "org.gnome.gitlab.cheywood.Buffer";
  };
}
