let
  users = import ../users.nix;
in
{
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
    };
    hm.alex.enable = true;
    desktop-env.alex.enable = true;

    wireguard.wg0.enable = true;
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

  boot = {
    supportedFilesystems = [ "nfs" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems."/mnt/t1/alex" = {
    device = "stationary.ahbk:/mnt/t1/alex";
    fsType = "nfs";
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

}
