{
  dependencies = { nixpakModules }: [
    nixpakModules.gui-base
  ];
  module = { sloth, ... }: {
    flatpak.appId = "org.nickvision.cavalier";
    bubblewrap = {
      bind.rw = [
        [
          (sloth.mkdir (sloth.concat' sloth.appConfigDir "/Nickvision Cavalier"))
          (sloth.concat' sloth.xdgConfigHome "/Nickvision Cavalier")
        ]
      ];
    };
  };
}
