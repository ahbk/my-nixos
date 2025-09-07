{
  config,
  lib,
  users,
  pkgs,
  ...
}:
{
  facter.reportPath = ./facter.json;
  imports = [
    ./disko.nix
  ];

  sops.secrets.luks-key = { };
  boot = {
    initrd = {
      secrets."/luks-key" = config.sops.secrets.luks-key.path;
    };
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

  services.xserver = {
    enable = true;
    desktopManager.cinnamon.enable = true;
    displayManager.lightdm = {
      enable = true;
    };
  };

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

  my-nixos = {

    sysadm.rescueMode = true;

    preserve = {
      enable = true;
      directories = [
        "/home"
        "/etc/NetworkManager"
      ];
    };

    users = with users; {
      inherit admin ami;
    };

    shell.admin.enable = true;
    shell.ami.enable = true;

    hm.ami.enable = true;
    wireguard.wg0.enable = true;
  };
}
