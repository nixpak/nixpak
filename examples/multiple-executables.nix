{ mkNixPak, vim }:

mkNixPak {
  config = { sloth, ... }: {
    bubblewrap = {
      bind.rw = [ sloth.homeDir ];
      bind.ro = [ (sloth.concat' sloth.homeDir "Documents") ];
    };
    app = {
      package = vim;

      # list of executables to wrap in addition to the default /bin/vim
      extraEntrypoints = [
        "/bin/ex"
        "/bin/rview"
        "/bin/rvim"
        "/bin/vi"
        "/bin/view"
        "/bin/vimdiff"
        "/bin/vimtutor"
        "/bin/xxd"
      ];
    };
  };
}