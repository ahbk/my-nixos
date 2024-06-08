{ inputs, ... }: {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./desktop-env.nix
    ./ide.nix
    ./shell.nix
    ./user.nix
    ./vd.nix
  ];
}
