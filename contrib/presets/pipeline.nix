{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
    nixpakModules.network
  ];
  module = { sloth, ... }: {
    flatpak.appId = "de.schmidhuberj.tubefeeder";
    bubblewrap = {
      bind.rw = [
        [
          (sloth.mkdir (sloth.concat' sloth.appCacheDir "/tubefeeder"))
          (sloth.concat' sloth.xdgCacheHome "/tubefeeder")
        ]
        [
          (sloth.mkdir (sloth.concat' sloth.appDataDir "/tubefeeder"))
          (sloth.concat' sloth.xdgDataHome "/tubefeeder")
        ]
      ];
    };
  };
}
