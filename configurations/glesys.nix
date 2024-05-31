{ config, ... }: {
  networking.hostName = "glesys";
  system.stateVersion = "23.11";

  ahbk = with edgechunks; {
    user = { inherit alex frans; };
    shell.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = false;
      mysql = false;
      userAsTopDomain = false;
    };

    nginx = {
      enable = true;
      email = frans.email;
    };

    mailServer.enable = true;

    inherit chatddx sverigesval;
    wordpress.sites."esse.nu" = wordpress.sites."esse.nu";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];
}
