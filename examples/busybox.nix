{ mkNixPak, busybox }:

mkNixPak {
  config = {
    dbus.policies = {
      "org.freedesktop.systemd1" = "talk";
      "org.gtk.vfs.*" = "talk";
      "org.gtk.vfs" = "talk";
    };
    bubblewrap = {
      bind.rw = [ "$HOME" ];
      bind.ro = [ "$HOME/Documents" ];
      env = {
        TEST = "This is an environment variable test";
        PATH = "${busybox}/bin";
      };
    };
    app.package = busybox;
  };
}