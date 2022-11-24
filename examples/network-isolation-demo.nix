{ mkNixPak, curl }:

mkNixPak {
  config = { sloth, ...}: {
    dbus.enable = false;
    bubblewrap = {
      bind.ro = [ sloth.homeDir ];
      network = false;
    };
    app.package = curl;
  };
}