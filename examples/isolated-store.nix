{ mkNixPak, busybox, writeShellScriptBin }:

mkNixPak {
  config = { sloth, ...}: {
    dbus.enable = false;
    bubblewrap = {
      bindEntireStore = false;
      network = false;
    };
    app.package = writeShellScriptBin "isolated-store" ''
      echo "Store Paths:"
      ${busybox}/bin/ls -1 /nix/store
    '';
  };
}
