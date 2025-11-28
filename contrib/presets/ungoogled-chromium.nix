{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
    nixpakModules.network
  ];
  module = { config, sloth, ... }: {
    flatpak.appId = "org.chromium.Chromium";
    bubblewrap = {
      bind.rw = [
        [
          (sloth.mkdir (sloth.concat [
            sloth.appCacheDir
            "/nixpak-app-shared-tmp"
          ]))
          "/tmp"
        ]
        [
          (sloth.mkdir (sloth.concat [
            sloth.appDataDir
            "/profile"
          ]))
          (sloth.concat [
            sloth.xdgConfigHome
            "/chromium"
          ])
        ]
        (sloth.concat' sloth.homeDir "/Downloads")
      ];
    };
  };
}
