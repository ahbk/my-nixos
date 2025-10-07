{ inputs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./desktop-env.nix
    ./ide.nix
    ./shell.nix
    ./user.nix
    ./vd.nix
  ];
}
