{ mkNixPak, busybox }:

mkNixPak {
  config = { sloth, ... }: {
    dbus.policies = {
      "org.freedesktop.systemd1" = "talk";
      "org.gtk.vfs.*" = "talk";
      "org.gtk.vfs" = "talk";
    };
    timeZone = {
      enable = true;
      provider = "bundle";
      zone = "Asia/Tokyo";
    };
    bubblewrap = {
      bind.rw = [ sloth.homeDir ];
      bind.ro = [ (sloth.concat' sloth.homeDir "Documents") ];
      env = {
        TEST = "This is an environment variable test";
        PATH = "${busybox}/bin";
      };
    };
    app.package = busybox;
  };
}
