# NixPak - Sandboxing for Nix

> Nix? Flatpak? Why not both?

NixPak is essentially a fancy declarative wrapper around
[bwrap](https://github.com/containers/bubblewrap).
You can use it to sandbox all sorts of Nix-packaged applications,
including graphical ones.

It also optionally integrates with the following tools:
- [pasta](https://passt.top/) for highly customizable network isolation
- [xdg-dbus-proxy](https://github.com/flatpak/xdg-dbus-proxy) for D-Bus service access control
- [wayland-proxy-virtwl](https://github.com/talex5/wayland-proxy-virtwl) for Wayland protocol access control

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
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpak }: {
    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      mkNixPak = nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
      };

      sandboxed-hello = mkNixPak {
        config = { sloth, ... }: {

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
            # supports runtime resolution of environment variables
            # see "Sloth values" below
            bind.rw = [
              (sloth.concat' sloth.homeDir "/Documents")
              (sloth.env "XDG_RUNTIME_DIR")
              # a nested list represents a src -> dest mapping
              # where src != dest
              [
                (sloth.concat' sloth.homeDir "/.local/state/nixpak/hello/config")
                (sloth.concat' sloth.homeDir "/.config")
              ]
            ];
            bind.ro = [
              (sloth.concat' sloth.homeDir "/Downloads")
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
## Sloth values

Sandbox tools often need to deal with dynamic paths. Hardcoding a specific user's home directory in
a sandbox configuration is not very useful. To deal with this, NixPak configuration supports values
whose evaluation is delayed until runtime, called "sloth values" for their extraordinary laziness.

Sloth values are constructed using attributes from the `sloth` attribute set, which is available
via module arguments.

```nix
{ sloth, ... }:

{
  bubblewrap.bind.ro = [ sloth.homeDir ];
}
```

### Sloth value types

The following entries use Haskell-style type annotations. The `Sloth` type refers to a sloth value,
which can be a string or a rich sloth value as created by `sloth.*` functions.

#### `sloth.env :: string -> Sloth`

Takes an environment variable name and resolves it to its value at runtime.

```nix
sloth.env "HOME" # results in "/home/user" at runtime
```

#### `sloth.mkdir :: Sloth -> Sloth`

Ensures the presence of a directory. If it does not exist, creates it with permisions `0700`,
including all its parent components (like `mkdir -p`). Returns the resolved sloth value afterwards.

```nix
sloth.mkdir (sloth.env "MY_CACHE_DIRECTORY")
```

#### `sloth.concat :: [Sloth] -> Sloth`

Concatenates sloth values. Useful for combining an environment variable with a string.

```nix
sloth.concat [
  sloth.homeDir
  "/.config"
]
```

#### `sloth.concat' :: Sloth -> Sloth -> Sloth`

Concatenates two sloth values, with the convenience of not having to create a list.

```nix
sloth.concat' sloth.homeDir "/.config"
```

#### `sloth.instanceId :: Sloth`

A unique alphanumeric string derived from the launcher's PID. Used to differentiate between
multiple simultaneously active sandbox instances.

```nix
sloth.concat [
  (sloth.env "XDG_RUNTIME_DIR")
  "/my-app-"
  sloth.instanceId
]
# looks something like "/run/user/1000/my-app-jim1rivq0gblz0vn6k32wgv7aq"
```

#### `sloth.uid :: Sloth`

UID of the user at runtime.

```nix
sloth.uid # results in "1000" at runtime
```

#### `sloth.gid :: Sloth`

GID of the user at runtime.

```nix
sloth.gid # results in "100" at runtime
```
