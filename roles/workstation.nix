{ inputs, ... }:
{
  imports = [
    ../modules/desktop-env.nix
    ../modules/hm.nix
    ../modules/ide.nix
    ../modules/mysql.nix
    ../modules/postgresql.nix
    ../modules/shell.nix
    ../modules/vd.nix
  ];
  nixpkgs.overlays = [
    (import ../overlays/workstation.nix { inherit inputs; })
  ];
}
