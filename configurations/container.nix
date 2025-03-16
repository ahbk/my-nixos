let
  users = import ../users.nix;
in
{
  my-nixos = {
    users.admin = users.admin;
    shell.admin.enable = true;
  };
}
