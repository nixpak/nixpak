# NixPak presets

This is a collection of building blocks and pre-made configurations for various applications.

## `modules`

These are reeady-to-import modules that act as general building blocks.
You can use these to quickly apply common settings in your sandbox definitions.
They are exposed via the `nixpakModules` attribute in this flake's outputs.
A Module "example" would be available as `nixpakModules.example`.

## `presets`

These modules define a complete configuration for a specific application, such as `ungoogled-chromium`.
These are intended to act as application-specific baselines for you to build upon.
The `app.package` option is left unset, so you can bring your own customized package.
A preset called "example" will be exposed as `nixpakModules.preset-example`.

## `packages`

These are complete package definitions, made available through the standard flake outputs under `packages`, for consumption by `nix shell`, `nix run`, etc.
They import their respective preset and set `app.package`.

## Module spec definition

Everything in `modules`, `presets` and `packages` gets automatically imported and turned into the appropriate attribute.
An attribute `example` can be created either by a file `example.nix` or `example/default.nix`.
The content of this file should match this type:

```
ModuleSpec :: {
  module :: Module,
  dependencies :: { nixpakModules :: {Module} } -> [Module]
}
```

Where
  - `module` refers to an actual NixPak module.
  - `dependencies` allows you to specify which modules this module depends on.
