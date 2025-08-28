{
  config,
  lib,
  users,
  ...
}:
{
  facter.reportPath = ./facter.json;
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

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
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

  networking = {
    useDHCP = lib.mkDefault true;
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

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  programs.light.brightnessKeys.enable = true;

  my-nixos = {
    sysadm.rescueMode = true;
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
      target = "backup.km";
    };
  };
}
