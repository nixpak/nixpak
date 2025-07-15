{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
    nixpakModules.network
  ];
  module = {
    flatpak.appId = "app.drey.Dialect";
    app.extraEntrypoints = [
      "/share/dialect/search_provider"
    ];
  };
}
