{ config, lib, pkgs, ... }:
with lib;
let
  # most of the things here should probably be incorporated into a module
  
  # TODO: make a proper type for env vars or pathspecs
  coerceToEnv = val: let
    parsed = strings.match "^\\$([a-zA-Z0-9_]*)(/(.*))?$" val;
    key = elemAt parsed 0;
    append = elemAt parsed 2;
  in if isString val && parsed != null then
      if append != null then
        concat (env key) (concat "/" (coerceToEnv append))
      else
        env key
    else if isAttrs val && val ? _sloth then
      val._sloth
    else
      val;

  instanceId = { type = "instanceId"; };
  concat = a: b: { type = "concat"; inherit a b; };
  env = key: { type = "env"; inherit key; };

  splitPath = path: if isList path then {
    a = elemAt path 0;
    b = elemAt path 1;
  } else {
    a = path;
    b = path;
  };

  bind' = arg: path: let
    split = splitPath path;
    coerced = mapAttrs (_: coerceToEnv) split;
  in [ arg coerced.a coerced.b ];
  bind = bind' "--bind-try";
  bindRo = bind' "--ro-bind-try";
  bindDev = bind' "--dev-bind-try";
  setEnv = key: val: [ "--setenv" key val ];
  mountTmpfs = path: [ "--tmpfs" path ];
  
  bindPaths = map bind config.bubblewrap.bind.rw;
  bindRoPaths = map bindRo config.bubblewrap.bind.ro;
  bindDevPaths = map bindDev config.bubblewrap.bind.dev;
  envVars = mapAttrsToList setEnv config.bubblewrap.env;
  tmpfs = map mountTmpfs config.bubblewrap.tmpfs;

  app = config.app.package;
  info = pkgs.closureInfo { rootPaths = app; };
  launcher = pkgs.callPackage ../launcher {};
  dbusOutsidePath = concat (env "XDG_RUNTIME_DIR") (concat "/nixpak-bus-" instanceId);
  
  bwrapArgs = flatten [
    "--unshare-all"
    bindPaths
    bindRoPaths
    envVars
    tmpfs
    
    (optionals config.bubblewrap.network "--share-net")
    (optionals config.bubblewrap.apivfs.dev ["--dev" "/dev"])
    (optionals config.bubblewrap.apivfs.proc ["--proc" "/proc"])

    bindDevPaths
    
    (optionals config.dbus.enable [
      (bind [ dbusOutsidePath "$XDG_RUNTIME_DIR/nixpak-bus" ])
      "--setenv" "DBUS_SESSION_BUS_ADDRESS"
      (concat "unix:path=" (coerceToEnv "$XDG_RUNTIME_DIR/nixpak-bus"))
    ])

    [ "--ro-bind" config.flatpak.infoFile "/.flatpak-info" ]

    # TODO: use closureInfo instead
    [ (bindRo "/nix/store") "${app}/${config.app.binPath}" ]
  ];
  dbusProxyArgs = [ (env "DBUS_SESSION_BUS_ADDRESS") dbusOutsidePath ] ++ config.dbus.args ++ [ "--filter" ];
  
  bwrapArgsJson = pkgs.writeText "bwrap-args.json" (builtins.toJSON bwrapArgs);
  dbusProxyArgsJson = pkgs.writeText "xdg-dbus-proxy-args.json" (builtins.toJSON dbusProxyArgs);

  mainProgram = builtins.baseNameOf config.app.binPath;

  envOverrides = pkgs.runCommand "nixpak-overrides-${app.name}" {} ''
    mkdir $out
    cd ${app}
    grep -Rl ${app}/${config.app.binPath} | xargs -r -I {} cp -r --parents {} $out || true
    find $out -type f | while read line; do
      substituteInPlace $line --replace ${app}/${config.app.binPath} ${config.script}/${config.app.binPath}
    done
    find . -type l | while read line; do
      linkTarget="$(readlink $line)"
      if [[ "$linkTarget" == *${app}* ]]; then
        mkdir -p $(dirname $out/$line)
        ln -sf "$(echo $linkTarget | sed 's,${app},${config.script},g')" $out/$line
      fi
    done

    for desktopFileRel in share/applications/*.desktop; do
      if [[ -e $desktopFileRel ]] && grep -qm1 '[Desktop Entry]' $desktopFileRel; then
        chmod +w -R $out
        cp --parents $desktopFileRel $out
        chmod +w $out/$desktopFileRel
        echo -e '\nX-Flatpak=${config.flatpak.appId}' >> $out/$desktopFileRel
      fi
    done
  '';

  # This is required because the Portal service reads /proc/$pid/root/.flatpak-info
  # from the calling PID, when dbus-proxy is in use, this PID is the dbus-proxy process
  # itself, not the actual application. Mitigation: Run dbus-proxy in a "sandbox"
  dbusProxyWrapper = pkgs.writeShellScript "xdg-dbus-proxy-wrapper" ''
    exec ${config.bubblewrap.package}/bin/bwrap ${concatStringsSep " " (flatten [
      (bindRo "/etc")
      (bindRo "/nix/store")
      (bind "/var")
      (bind "/tmp")
      (bind "/run")
      "--ro-bind-try ${config.flatpak.infoFile or "/.flatpak-info-not-found"} /.flatpak-info"
    ])} ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy "$@"
  '';
in {
  options = {
    script = mkOption {
      description = "The final wrapper script.";
      internal = true;
      readOnly = true;
      type = types.package;
    };
    env = mkOption {
      description = "The app with the wrapper script replacing the regular binary.";
      internal = true;
      readOnly = true;
      type = types.package;
    };
  };

  config.script = pkgs.runCommandLocal "nixpak-${app.name or "app"}" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = { inherit mainProgram; };
  } (''
    #mkdir -p $out/bin
    makeWrapper ${launcher}/bin/launcher $out/bin/${mainProgram} \
      ${concatStringsSep " " (flatten [
        "--set BWRAP_EXE ${config.bubblewrap.package}/bin/bwrap"
        "--set BUBBLEWRAP_ARGS ${bwrapArgsJson}"
        (optionals config.dbus.enable "--set XDG_DBUS_PROXY_EXE ${dbusProxyWrapper}")
        (optionals config.dbus.enable "--set XDG_DBUS_PROXY_ARGS ${dbusProxyArgsJson}")
      ])}
  '');

  config.env = pkgs.buildEnv {
    inherit (config.script) name;
    paths = [
      (lib.hiPrio config.script)
      (lib.hiPrio envOverrides)
      app
    ];
  };
}
