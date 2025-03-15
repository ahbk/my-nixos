let
  users = import ../users.nix;
in
{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  my-nixos = {
    users = with users; {
      inherit alex frans backup;
    };
    shell.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = true;
      mysql = true;
      redis = true;
    };
    hm.alex.enable = true;
    desktop-env.alex.enable = true;
    vd.alex.enable = true;

    wireguard.wg0.enable = true;

    sendmail.alex.enable = true;

    backup.local = {
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
    networkmanager.unmanaged = [ "interface-name:ve-*" ];
    firewall.allowedTCPPorts = [
      3000
      5173
      8000
    ];
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

}
