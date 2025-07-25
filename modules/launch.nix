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
  rootPaths = [ app ] ++ config.bubblewrap.extraStorePaths;
  info = pkgs.closureInfo { inherit rootPaths; };
  launcher = pkgs.callPackage ../launcher {};
  dbusOutsidePath = concat (env "XDG_RUNTIME_DIR") (concat "/nixpak-bus-" instanceId);
  
  pastaEnable = config.bubblewrap.network && config.pasta.enable;

  bwrapArgs = flatten [
    # This is the equivalent of --unshare-all, see bwrap(1) for details.
    "--unshare-user-try"
    (optionals (!config.bubblewrap.shareIpc) "--unshare-ipc")
    "--unshare-pid"
    "--unshare-net"      
    "--unshare-uts"
    "--unshare-cgroup-try"

    bindPaths
    bindRoPaths
    (optionals (config.bubblewrap.clearEnv) "--clearenv")
    envVars
    tmpfs
    
    (optionals (config.bubblewrap.network && !config.pasta.enable) "--share-net")
    (optionals config.bubblewrap.apivfs.dev ["--dev" "/dev"])
    (optionals config.bubblewrap.apivfs.proc ["--proc" "/proc"])

    bindDevPaths
    
    (optionals config.dbus.enable [
      (bind [ dbusOutsidePath "$XDG_RUNTIME_DIR/nixpak-bus" ])
      "--setenv" "DBUS_SESSION_BUS_ADDRESS"
      (concat "unix:path=" (coerceToEnv "$XDG_RUNTIME_DIR/nixpak-bus"))
    ])

    (optionals config.bubblewrap.bindEntireStore (bindRo "/nix/store"))
  ];
  dbusProxyArgs = [ (env "DBUS_SESSION_BUS_ADDRESS") dbusOutsidePath ] ++ config.dbus.args ++ [ "--filter" ];

  originalBwrapArgs = pkgs.writeText "bwrap-args.json" (builtins.toJSON bwrapArgs);
  bwrapArgsJson = if config.bubblewrap.bindEntireStore then originalBwrapArgs else pkgs.runCommand "bwrap-args.json" {
    nativeBuildInputs = [ pkgs.jq ];
  } ''
    jq -nR '[inputs] | map("--ro-bind", ., .)' ${info}/store-paths > store-paths.json
    jq -s '.[0] + .[1]' ${originalBwrapArgs} store-paths.json > $out
  '';

  dbusProxyArgsJson = pkgs.writeText "xdg-dbus-proxy-args.json" (builtins.toJSON dbusProxyArgs);

  pastaArgsJson = pkgs.writeText "pasta-args.json" (builtins.toJSON config.pasta.args);

  waylandProxyArgsJson = pkgs.writeText "wayland-proxy-args.json" (builtins.toJSON config.waylandProxy.args);

  mainProgram = builtins.baseNameOf config.app.binPath;

  mkWrapperScript = {
    name,
    mainProgram ? null,
    executablePath ? "/bin/${mainProgram}",
    passthru ? {}
  }: pkgs.runCommandLocal "nixpak-${name}" {
    inherit passthru;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = optionalAttrs (mainProgram != null) { inherit mainProgram; };
  } (''
    makeWrapper ${launcher}/bin/launcher $out${executablePath} \
      ${concatStringsSep " " (flatten [
        "--set BWRAP_EXE ${config.bubblewrap.package}/bin/bwrap"
        "--set NIXPAK_APP_EXE ${app}${executablePath}"
        "--set BUBBLEWRAP_ARGS ${bwrapArgsJson}"
        "--set FLATPAK_METADATA_TEMPLATE ${config.flatpak.infoFile}"
        (optionals config.dbus.enable "--set XDG_DBUS_PROXY_EXE ${dbusProxyWrapper}")
        (optionals config.dbus.enable "--set XDG_DBUS_PROXY_ARGS ${dbusProxyArgsJson}")
        (optionals pastaEnable "--set PASTA_EXE ${config.pasta.package}/bin/pasta")
        (optionals pastaEnable "--set PASTA_ARGS ${pastaArgsJson}")
        (optionals config.waylandProxy.enable "--set WAYLAND_PROXY_EXE ${config.waylandProxy.package}/bin/wayland-proxy-virtwl")
        (optionals config.waylandProxy.enable "--set WAYLAND_PROXY_ARGS ${waylandProxyArgsJson}")
      ])}
  '');

  extraEntrypointScripts = genAttrs config.app.extraEntrypoints (entrypoint: mkWrapperScript {
    name = "${app.name or "app"}${strings.sanitizeDerivationName entrypoint}";
    executablePath = entrypoint;
  });

  envOverrides = pkgs.runCommand "nixpak-overrides-${app.name}" {} (''
    mkdir $out
    cd ${app}
    find . -type l | while read line; do
      linkTarget="$(readlink $line)"
      if [[ "$linkTarget" == *${app}* ]]; then
        newTarget="$(echo $linkTarget | sed 's,${app},${config.script},g')"
        echo Rewriting symlink "$line": "$linkTarget" '->' "$newTarget"
        mkdir -p $(dirname $out/$line)
        ln -sf "$newTarget" $out/$line
      fi
    done

    for desktopFileRel in share/applications/*.desktop; do
      if [[ -e $desktopFileRel ]] && grep -qm1 '[Desktop Entry]' $desktopFileRel; then
        echo Flatpakizing desktop file: "$desktopFileRel"
        cp --parents --no-preserve=mode $desktopFileRel $out
        sed -i 's/\[Desktop Entry\]$/[Desktop Entry]\nX-Flatpak=${config.flatpak.appId}/g' $out/$desktopFileRel
      fi
    done

    grep -Rl --binary-files=without-match ${app}/${config.app.binPath} | xargs -r cp -r --parents --no-preserve=mode --update=none -t $out || true
    (grep -Rl --binary-files=without-match ${app}/${config.app.binPath} $out || true) | while read line; do
      if ! test -L "$line"; then
        echo Rewriting executable paths in "$line"
        substituteInPlace "$line" --replace-fail ${app}/${config.app.binPath} ${config.script}/${config.app.binPath}
      fi
    done
  '' + lib.optionalString (config.flatpak.desktopFile != "${config.flatpak.appId}.desktop") ''
    originalDesktopFile="$out/share/applications/${config.flatpak.desktopFile}"
    newDesktopFile="$out/share/applications/${config.flatpak.appId}.desktop"
    echo Renaming desktop file "$originalDesktopFile" to "$newDesktopFile"
    mv "$originalDesktopFile" "$newDesktopFile"
    ln -s /dev/null "$originalDesktopFile"
  '' + concatStringsSep "\n" (map (entrypoint: let
    entrypointScript = extraEntrypointScripts.${entrypoint};
  in ''
    grep -Rl --binary-files=without-match ${app}${entrypoint} | xargs -r cp -r --parents --no-preserve=mode --update=none -t $out || true
    (grep -Rl --binary-files=without-match ${app}${entrypoint} $out || true) | while read line; do
      if ! test -L "$line"; then
        echo Rewriting executable paths in "$line"
        substituteInPlace "$line" --replace-fail ${app}${entrypoint} ${entrypointScript}${entrypoint}
      fi
    done
    rm -f $out${entrypoint}
  '') config.app.extraEntrypoints));

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
      "--ro-bind-try \"$FLATPAK_METADATA_FILE\" /.flatpak-info"
    ])} ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy "$@"
  '';

  passthru = {
    extendModules = config._module.args.extendModules;
    config = config;
  };
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

  config.script = mkWrapperScript {
    name = app.name or "app";
    inherit mainProgram passthru;
  };

  config.env = pkgs.buildEnv {
    inherit (config.script) name meta passthru;
    paths = [
      (hiPrio config.script)
      (hiPrio envOverrides)
      app
    ] ++ map hiPrio (attrValues extraEntrypointScripts);
  };
}
