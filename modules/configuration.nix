{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  networking.hostName = "host";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Stockholm";

  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "a";
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  system.stateVersion = "23.11";
}

