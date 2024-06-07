let
  users = import ../users.nix;
in
{
  my-nixos = {
    user.frans = users.frans;
    shell.frans.enable = true;
  };
}
