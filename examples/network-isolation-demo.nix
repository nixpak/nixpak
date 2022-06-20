{ mkNixPak, curl }:

mkNixPak {
  config = {
    dbus.enable = false;
    bubblewrap = {
      bind.ro = [ "$HOME" ];
      network = false;
    };
    app.package = curl;
  };
}