{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware/friday.nix
    ./common.nix
  ];
}
