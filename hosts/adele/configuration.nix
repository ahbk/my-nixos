{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ../../modules/facter.nix
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

  security = {
    rtkit.enable = true;
    polkit.enable = true;
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
          webcamoid
          libcamera
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
    facter.enable = true;
    locksmith = {
      enable = true;
      luksDevice = "/dev/sda3";
    };
    sops.enable = true;
    ssh.enable = true;

    preserve = {
      enable = true;
      directories = [
        "/home"
        "/etc/NetworkManager"
      ];
    };

    users = {
      admin = {
        class = "user";
        groups = [ "wheel" ];
      };
      ami = {
        class = "user";
      };
    };

    shell.ami.enable = true;
    hm.ami.enable = true;
  };
}
