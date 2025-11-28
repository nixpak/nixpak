{
  perSystem = { config, lib, ... }: with lib; {
    options.builders = mkOption {
      description = "Collection of builder functions.";
      type = with types; attrsOf (functionTo raw);
      default = {};
    };

    config._module.args = { inherit (config) builders; };
  };
}
