{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
    nixpakModules.mpris2-player
  ];

  module = { sloth, ... }: {
    flatpak.appId = "io.bassi.Amberol";
    bubblewrap = {
      bind.rw = [
        [
          (sloth.mkdir (sloth.concat' sloth.appCacheDir "/amberol"))
          (sloth.concat' sloth.xdgCacheHome "/amberol")
        ]
      ];
      bind.ro = [
        (sloth.concat' sloth.homeDir "/Music")
      ];
    };
  };
}
