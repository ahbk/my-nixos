let
  users = import ../users.nix;
in {
  ahbk = {
    user.frans = users.frans;
    shell.frans.enable = true;
  };
}
