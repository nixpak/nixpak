{ config, lib, ... }:
with lib;

{
  imports = [
    {
      options.app = {
        package = mkOption {
          description = "The app package.";
          type = types.package;
        };
      };
    }
    {
      options.app.binPath = mkOption {
        description = "The app's executable within the package. May need to be set manually if automatic detection fails.";
        type = types.str;
        default = let
          app = config.app.package;
        in
          if app ? meta.mainProgram then
            "bin/${app.meta.mainProgram}"
          else if app ? pname then
            "bin/${app.pname}"
          else throw "cannot automatically determine binPath, please provide it";
      };
    }
  ];
}
