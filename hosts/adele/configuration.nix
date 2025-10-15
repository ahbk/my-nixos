{
  config,
  inputs,
  host,
  lib,
  pkgs,
  ...
}:
{
  my-nixos = {
    sysadm.rescueMode = true;

    users.ami.enable = true;
    hm.ami.enable = true;
    shell.ami.enable = true;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  sops.secrets.wifi-keys = {
    mode = "644";
    owner = "ami";
  };

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager = {
      enable = true;
    };
  };

  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint ];
  };

  security = {
    rtkit.enable = true;
    polkit.enable = true;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.xserver = {
    enable = true;
    desktopManager.cinnamon.enable = true;
    displayManager.lightdm = {
      enable = true;
    };
  };

  nix.settings.trusted-users = [ "ami" ];
  home-manager.users.ami =
    { pkgs, ... }:
    {
      programs.firefox = {
        enable = true;
      };

      home = {
        stateVersion = "25.11";
        packages = with pkgs; [
          shotwell
          signal-desktop
          libreoffice
          hunspell
          hunspellDicts.sv_SE
          hunspellDicts.en_US
        ];
      };
    };
}
