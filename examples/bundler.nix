{ mkNixPak, drv }:

mkNixPak {
  config = { sloth, ...}: {
    app.package = drv;
    bubblewrap = {
      bind.rw = [ sloth.homeDir ];
      env.NIXPAK_INFO = "Hello from NixPak - app: ${drv.name}";
    };
  };
}
