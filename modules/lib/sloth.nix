{ lib, ... }:

{
  _module.args.sloth = {
    mk = _sloth: { inherit _sloth; };
    env = key: {
      inherit key;
      type = "env";
    };

    concat = let
      mkConcatStruct = a: b:
        if a == null then b
        else if b == null then a
        else if (lib.isString a && lib.isString b) then a + b
        else {
          type = "concat";
          inherit a b;
        };
    in lib.foldl' mkConcatStruct null;
  };
}
