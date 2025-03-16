# This file will not be evaluated by any host
# Its only purpose is to bootstrap new machines

{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Stockholm";

  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  users = {
    mutableUsers = false;
    users.admin = {
      uid = 1000;
      group = "admin";
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      initialPassword = "password";
      packages = with pkgs; [
        neovim
      ];
    };
    groups.admin.gid = 1000;
  };


  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
      vim
      git
      tmux
      w3m
  ];

  services.openssh.enable = true;

  system.stateVersion = "24.11";
}

