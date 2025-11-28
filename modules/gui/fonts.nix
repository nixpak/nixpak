{ config, lib, pkgs, ... }:

let
  cfg = config.fonts;
in

with lib;

{
  options.fonts = {
    enable = mkEnableOption "font support";
    fonts = mkOption {
      description = "Font packages to install.";
      type = with types; listOf package;
      default = with pkgs; [
        cantarell-fonts
        dejavu_fonts
        liberation_ttf
        gyre-fonts
        source-sans
        source-code-pro
        noto-fonts-color-emoji
      ];
    };
  };

  config = let
    fontCache = pkgs.makeFontsCache {
      inherit (pkgs) fontconfig;
      fontDirectories = cfg.fonts;
    };
    fontConfigFile = pkgs.writeTextDir "etc/fonts/conf.d/00-nixpak-fonts.conf" ''
      <?xml version='1.0'?>
      <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
      <fontconfig>
        <!-- Font directories -->
        ${lib.concatStringsSep "\n" (map (font: "<dir>${font}</dir>") cfg.fonts)}
        ${lib.optionalString (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) ''
        <!-- Pre-generated font caches -->
        <cachedir>${fontCache}</cachedir>
        ''}
      </fontconfig>
    '';
    fc = pkgs.buildEnv {
      name = "nixpak-font-env";
      paths = [
        fontConfigFile
        pkgs.fontconfig.out
      ];
      pathsToLink = [ "/etc/fonts" ];
    };
  in mkIf cfg.enable {
    bubblewrap.extraStorePaths = [ fc ];
    bubblewrap.bind.ro = [
      [ "${fc}/etc/fonts" "/etc/fonts" ]
    ];
  };
}
