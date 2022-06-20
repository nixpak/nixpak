{ mkNixPak, drv }:

mkNixPak {
  config = {
    app.package = drv;
    bubblewrap = {
      bind.rw = [ "$HOME" ];
      env.NIXPAK_INFO = "Hello from NixPak - app: ${drv.name}";
    };
  };
}
