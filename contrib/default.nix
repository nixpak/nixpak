{ lib, self, ... }:
let
  flake = "github:nixpak/nixpak";

  filterFiles = lib.filterAttrs (name: type: type == "directory" || type == "regular" && lib.hasSuffix ".nix" name);

  collectFiles = baseDir: filterFiles (builtins.readDir baseDir);

  attrNameFromFile = name: type: if type == "directory" then name else lib.removeSuffix ".nix" name;

  collectAttrs = f: baseDir: lib.mapAttrs' (name: type: f
    (attrNameFromFile name type)
    (import (baseDir + "/${name}"))
  ) (collectFiles baseDir);

  getModuleDependencies = moduleSpec: (moduleSpec.dependencies or (lib.const [])) { inherit (self) nixpakModules; };

  createModule = moduleSpec: {
    _class = "nixpak";
    imports = [ moduleSpec.module ] ++ (getModuleDependencies moduleSpec);
  };

  createModule' = isPreset: moduleName: moduleSpec: let
    name = "${lib.optionalString isPreset "preset-"}${moduleName}";
  in {
    inherit name;
    value = createModule moduleSpec // {
      _file = "${flake}#nixpakModules.${name}";
    };
  };

  collectModules = isPreset: baseDir: collectAttrs (createModule' isPreset) baseDir;
in
{
  imports = [
    ./parts/builders.nix
    ./parts/nixpak-builder.nix
  ];

  flake.nixpakModules = (collectModules false ./modules) // (collectModules true ./presets);

  perSystem = { builders, ... }: {
    packages = collectAttrs (name: moduleSpec: let
      package = builders.mkNixPakConfiguration {
        config.imports = [ (createModule moduleSpec) self.nixpakModules."preset-${name}" ];
      };
    in {
      inherit name;
      value = package.config.env;
    }) ./packages;
  };
}
