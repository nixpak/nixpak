{ mkNixPak, busybox, iproute2, curl }:

mkNixPak {
  config = { sloth, ... }: {
    dbus.policies = { };
    pasta.enable = true;
    bubblewrap = {
      bind.rw = [
        [
          (sloth.mkdir (sloth.concat' "/tmp/nixpak-pasta-example-" sloth.uid))
          sloth.homeDir
        ]
      ];
      env = {
        PATH = "${curl}/bin:${iproute2}/bin:${busybox}/bin";
      };
    };
    app.package = busybox;
  };
}
