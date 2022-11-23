# NixPak - Sandboxing for Nix

> Nix? Flatpak? Why not both?

NixPak is essentially a fancy declarative wrapper around
[bwrap](https://github.com/containers/bubblewrap) and
[xdg-dbus-proxy](https://github.com/flatpak/xdg-dbus-proxy).
You can use it to sandbox all sorts of Nix-packaged applications,
including graphical ones.

## Features

- Bind-mount any host path, rw and ro
- Bind-mount devices
- Full network isolation
- D-Bus access control
- Flatpak Shim
  - Fools xdg-desktop-portal into thinking your Nix application is a Flatpak!
  - Enables use of the [Document Portal](https://docs.flatpak.org/en/latest/portal-api-reference.html#gdbus-org.freedesktop.portal.Documents),
    so you don't need to bind-mount your entire home directory but can still open and save files in arbitrary locations.

## Example usage

Also see the [examples directory](./examples)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpak = {
      url = "github:max-privatevoid/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
    
  outputs = { self, nixpkgs, nixpak }: {
    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
      };

      sandboxed-hello = mkNixPak {
        config = {

          # the application to isolate
          app.package = pkgs.hello;

          # path to the executable to be wrapped
          # this is usually autodetected but
          # can be set explicitly nonetheless
          app.binPath = "bin/hello";

          # enabled by default, flip to disable
          # and to remove dependency on xdg-dbus-proxy
          dbus.enable = true;

          # same usage as --see, --talk, --own
          dbus.policies = {
            "org.freedesktop.DBus" = "talk";
            "ca.desrt.dconf" = "talk";
          };

          # needs to be set for Flatpak emulation
          # defaults to com.nixpak.${name}
          # where ${name} is generated from the drv name like:
          # hello -> Hello
          # my-app -> MyApp
          flatpak.appId = "org.myself.HelloApp";

          bubblewrap = {

            # disable all network access
            network = false;

            # lists of paths to be mounted inside the sandbox
            # supports limited runtime resolution of environment variables
            bind.rw = [
              "$HOME/Documents"
              "$XDG_RUNTIME_DIR"
              # a nested list represents a src -> dest moapping
              # where src != dest
              [ "$HOME/.local/state/nixpak/hello/config" "$HOME/.config" ]
            ];
            bind.ro = [
              "$HOME/Downloads"
            ];
            bind.dev = [
              "/dev/dri"
            ];
          };
        };
      };
    in {
      # Just the wrapped /bin/${mainProgram} binary
      hello = sandboxed-hello.config.script;

      # A symlinkJoin that resembles the original package,
      # except the main binary is swapped for the
      # wrapper script, as are textual references
      # to the binary, like in D-Bus service files.
      # Useful for GUI apps.
      hello-env = sandboxed-hello.config.env;
    };
  };
}
```

