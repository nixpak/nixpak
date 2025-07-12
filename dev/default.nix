{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = [
        pkgs.go
      ];

      shellHook = ''
        export GOPATH="$PWD/.data/go";
      '';
    };
  };
}
