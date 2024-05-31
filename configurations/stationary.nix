{ config, pkgs', ... }: {
  networking.hostName = "stationary";
  system.stateVersion = "20.03";
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  services.netdata.enable = true;
  services.nginx.virtualHosts."10.0.0.1".locations."/netdata/" = {
    proxyPass = "http://localhost:19999/";
  };

  ahbk = with edgechunks; {
    user = { inherit frans backup; };
    shell.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = true;
      mysql = true;
      userAsTopDomain = false;
    };

    glesys.updaterecord = {
      enable = true;
      recordid = "3357682";
      cloudaccount = "cl44748";
      device = "enp3s0";
    };

    wg-server = {
      enable = true;
      host = "stationary";
      address = "10.0.0.1/24";
      peers = hosts;
    };

    nginx = {
      enable = true;
      email = frans.email;
    };

    wordpress.sites."test.esse.nu" = wordpress.sites."test.esse.nu";

    odoo = {
      enable = true;
      package = pkgs'.odoo;
      domain = "10.0.0.1";
      settings = {
        options = {
          db_user = "odoo";
          db_name = "odoo";
        };
      };
    };
  };
}
