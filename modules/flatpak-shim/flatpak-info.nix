{ config, lib, pkgs, ... }:
with lib;

let
  ini = generators.toINI {};
  writeINI = data: pkgs.writeText "flatpak-shim-info" (ini data);
  flatpakArchitectures = {
    "x86_64-linux"= "x86_64";
    "aarch64-linux" = "aarch64";
    "i686-linux" = "i386";
  };
  app = config.app.package;
  firstLetter = substring 0 1;
  restLetters = substring 1 (-1);
  upperFirst = string: (toUpper (firstLetter string)) + (restLetters string);
  appNameCase = name: concatStrings (map upperFirst (filter isString (builtins.split "-" name)));
in
{
  options.flatpak = {
    appId = mkOption {
      description = "Application ID";
      type = types.str;
      default = "com.nixpak.${appNameCase (app.pname or (builtins.parseDrvName app.name).name)}";
    };
    runtimeId = mkOption {
      description = "Fake runtime ID";
      type = types.str;
      default = "runtime/com.nixpak.Platform/${flatpakArchitectures.${pkgs.system} or "unknown-arch-${pkgs.system}"}/1";
    };
    sharedNamespaces = mkOption {
      description = "Indicate shared/unshared status of namespaces";
      type = with types; listOf (enum [ "ipc" "network" ]);
      default = (
        (lib.optional config.bubblewrap.network "network")
        ++ (lib.optional config.bubblewrap.shareIpc "ipc")
      );
    };

    info = mkOption {
      description = "Metadata for .flatpak-info";
      type = with types; attrsOf (attrsOf (oneOf [ str bool int ]));
    };

    infoFile = mkOption {
      description = "Flatpak metadata file";
      type = types.path;
      internal = true;
      readOnly = true;
    };
  };
  config.flatpak = {
    info = {
      Application = {
        name = config.flatpak.appId;
        runtime = config.flatpak.runtimeId;
      };
      Context.shared = "${concatStringsSep ";" config.flatpak.sharedNamespaces};";
      "Session Bus Policy" = config.dbus.policies;
    };
    infoFile = writeINI config.flatpak.info;
  };
}
