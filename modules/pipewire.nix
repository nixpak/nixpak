{ config, lib, pkgs, ... }:

with lib;

{
  options.pipewire = {
    enable = mkEnableOption "PipeWire access";
    package = mkOption {
      description = "PipeWire package to use for PulseAudio emulation in sandbox.";
      type = types.package;
      default = pkgs.pipewire;
    };
    snapId = mkOption {
      description = "Snap ID";
      type = types.str;
      default = config.flatpak.appId;
    };
    pulseaudio = mkEnableOption "PipeWire PulseAudio emulation in sandbox";
    playback = mkEnableOption "PipeWire playback access";
    capture = mkEnableOption "PipeWire capture access";
    properties = mkOption {
      type = with types; attrsOf str;
      description = "Extra context properties";
      default = {};
    };
    args = mkOption {
      type = with types; listOf str;
      description = "Arguments to pw-container";
      default = [];
    };
  };
  config.pipewire.properties = {
    # Use Snap's PipeWire access control
    "pipewire.snap.id" = config.pipewire.snapId;
    "pipewire.snap.audio.playback" = if config.pipewire.playback then "true" else "false";
    "pipewire.snap.audio.record" = if config.pipewire.capture then "true" else "false";
    # Use Flatpak's PipeWire access control
    #  This is only for reference, if someone wants to experiment with it and
    #  is currently not fully supported by NixPak. We did not follow this path,
    #  since Flatpak's access control is less flexible and directly built into
    #  PipeWire's C code, while Snap's access control supports separated access
    #  control for playback/record and is easier adjustable, since it is
    #  written in Lua.
    #"pipewire.sec.engine" = "org.flatpak";
    #"pipewire.access" = "restricted";
  };
  config.pipewire.args = [
    "--properties=${(builtins.toJSON config.pipewire.properties)}"
  ];
}
