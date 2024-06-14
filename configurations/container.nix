let
  users = import ../users.nix;
in
{
  my-nixos = {
    users.frans = users.frans;
    shell.frans.enable = true;
  };
}
