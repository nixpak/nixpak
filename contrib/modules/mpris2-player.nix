{
  module = { config, ... }: {
    dbus.policies = {
      "org.mpris.MediaPlayer2.${config.flatpak.appId}" = "own";
    };
  };
}
