{ config, lib, ... }:
let
  users = import ../../users.nix;
in
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/fcd9e077-268d-4561-bc4c-fc97b01511d7";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B837-236C";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
  networking.useDHCP = lib.mkDefault true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  programs.light.brightnessKeys.enable = true;

  my-nixos = {
    users = with users; {
      inherit admin alex;
    };
    shell.admin.enable = true;

    shell.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = true;
      redis = true;
    };
    hm.alex.enable = true;
    desktop-env.alex.enable = true;

    wireguard.wg0.enable = true;

    backup.km = {
      enable = true;
      target = "backup.ahbk";
    };
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "wlp1s0";
    };
    networkmanager = {
      enable = true;
      unmanaged = [ "interface-name:ve-*" ];
    };
    firewall.allowedTCPPorts = [
      3000
      5173
      8000
    ];
  };

  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets.luks-secret-key = { };

  boot = {
    initrd = {
      secrets."/secret.key" = config.sops.secrets.luks-secret-key.path;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

}
