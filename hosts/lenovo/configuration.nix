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

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    dhcpcd.enable = false;
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

    users = {
      alex = {
        description = "Alexander Holmbäck";
        class = "user";
        groups = [ "wheel" ];
      };
    };

    shell.alex.enable = true;

    ide.alex = {
      enable = true;
      postgresql = true;
      redis = true;
    };
    hm.alex.enable = true;
    desktop-env.alex.enable = true;

  };
}
