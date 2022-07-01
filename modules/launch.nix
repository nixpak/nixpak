{ config, lib, pkgs, ... }:
with lib;
let
  # most of the things here should probably be incorporated into a module
  
  # TODO: make a proper type for env vars or pathspecs
  coerceToEnv = str: let
    parsed = builtins.match "^\\$([a-zA-Z0-9_]*)(/(.*))?$" str;
    key = builtins.elemAt parsed 0;
    append = builtins.elemAt parsed 2;
  in if parsed != null then
      if append != null then
        concat (env key) (concat "/" (coerceToEnv append))
      else
        env key
    else
      str;

  concat = a: b: { type = "concat"; inherit a b; };
  env = key: { type = "env"; inherit key; };

  bind = path: let p = coerceToEnv path; in [ "--bind" p p ];
  bindRo = path: let p = coerceToEnv path; in [ "--ro-bind" p p ];
  setEnv = key: val: [ "--setenv" key val ];
  
  bindPaths = map bind config.bubblewrap.bind.rw;
  bindRoPaths = map bindRo config.bubblewrap.bind.ro;
  envVars = mapAttrsToList setEnv config.bubblewrap.env;

  app = config.app.package;
  info = pkgs.closureInfo { rootPaths = app; };
  launcher = pkgs.callPackage ../launcher {};
  
  bwrapArgs = flatten [
    "--unshare-all"
    bindPaths
    bindRoPaths
    envVars
    
    (optionals config.bubblewrap.network "--share-net")
    (optionals config.bubblewrap.apivfs.dev ["--dev" "/dev"])
    (optionals config.bubblewrap.apivfs.proc ["--proc" "/proc"])
    
    (optionals config.dbus.enable [
      (bind "$XDG_RUNTIME_DIR/nixpak-bus")
      "--setenv" "DBUS_SESSION_BUS_ADDRESS"
      (concat "unix:path=" (coerceToEnv "$XDG_RUNTIME_DIR/nixpak-bus"))
    ])

    # TODO: use closureInfo instead
    [ (bindRo "/nix/store") "${app}/${config.app.binPath}" ]
  ];
  dbusProxyArgs = [ (env "DBUS_SESSION_BUS_ADDRESS") (coerceToEnv "$XDG_RUNTIME_DIR/nixpak-bus") ] ++ config.dbus.args;
  
  bwrapArgsJson = pkgs.writeText "bwrap-args.json" (builtins.toJSON bwrapArgs);
  dbusProxyArgsJson = pkgs.writeText "xdg-dbus-proxy-args.json" (builtins.toJSON dbusProxyArgs);
in {
  options = {
    script = mkOption {
      description = "The final wrapper script.";
      internal = true;
      readOnly = true;
      type = types.package;
    };
  };

  config.script = pkgs.runCommandLocal (app.pname or app.name or "nixpak-app") {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } (''
    #mkdir -p $out/bin
    makeWrapper ${launcher}/bin/launcher $out/bin/$name \
      ${concatStringsSep " " (flatten [
        "--set BWRAP_EXE ${config.bubblewrap.package}/bin/bwrap"
        "--set BUBBLEWRAP_ARGS ${bwrapArgsJson}"
        (optionals config.dbus.enable "--set XDG_DBUS_PROXY_EXE ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy")
        (optionals config.dbus.enable "--set XDG_DBUS_PROXY_ARGS ${dbusProxyArgsJson}")
      ])}
  '');
}
