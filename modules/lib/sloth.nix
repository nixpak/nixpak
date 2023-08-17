{ config, lib, sloth, ... }:

let
  knownTypes = [
    "concat"
    "env"
    "instanceId"
    "mkdir"
  ];
in
{
  _module.args.sloth = {

    type = with lib; mkOptionType {
      name = "sloth value";
      check = x:
        # path style
        (types.path.check x)
        # sloth style
        || (isAttrs x && x ? type && any (t: x.type == t) knownTypes);
    };

    instanceId = {
      type = "instanceId";
    };

    env = key: {
      inherit key;
      type = "env";
    };
    envOr = key: or_: {
      inherit key;
      "or" = or_;
      type = "env";
    };

    concat = let
      isConcat = x: x.type or "" == "concat";

      backAttachable = x: isConcat x && lib.isString x.b;

      frontAttachable = x: isConcat x && lib.isString x.a;

      balanceConcats = a: b:
        if backAttachable a && lib.isString b then {
          inherit (a) a;
          b = a.b + b;
        }
        else if lib.isString a && frontAttachable b then {
          a = a + b.a;
          inherit (b) b;
        }
        else if backAttachable a && frontAttachable b then
          sloth.concat [ a.a (a.b + b.a) b.b ]
        else { inherit a b; };

      mkConcatStruct = a: b:
        if a == null then b
        else if b == null then a
        else if (lib.isString a && lib.isString b) then a + b
        else {
          type = "concat";
          inherit (balanceConcats a b) a b;
        };
    in lib.foldl' mkConcatStruct null;

    concat' = a: b: sloth.concat [ a b ];

    mkdir = dir: {
      inherit dir;
      type = "mkdir";
    };

    homeDir = sloth.env "HOME";

    appDir = sloth.concat [
      sloth.homeDir
      "/.var/app/${config.flatpak.appId}"
    ];

    appCacheDir = sloth.concat' sloth.appDir "/cache";

    appDataDir = sloth.concat' sloth.appDir "/data";

    xdgCacheHome = sloth.envOr "XDG_CACHE_HOME" (sloth.concat' sloth.homeDir "/.cache");

    xdgConfigHome = sloth.envOr "XDG_CONFIG_HOME" (sloth.concat' sloth.homeDir "/.config");

    runtimeDir = sloth.env "XDG_RUNTIME_DIR";
  };
}
