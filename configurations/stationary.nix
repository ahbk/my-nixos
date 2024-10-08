{ config, ... }:
let
  users = import ../users.nix;
  sites = import ../sites.nix;
in
{
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  services.netdata.enable = true;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.nginx.virtualHosts."stationary.ahbk".locations."/netdata/" = {
    proxyPass = "http://localhost:19999/";
  };

  services.prometheus = {
    enable = true;
    scrapeConfigs = with config.services.prometheus.exporters; [
      {
        job_name = "wireguard";
        static_configs = [
          {
            targets = [
              "glesys.ahbk:${toString wireguard.port}"
              "stationary.ahbk:${toString wireguard.port}"
              "laptop.ahbk:${toString wireguard.port}"
            ];
          }
        ];
      }
      {
        job_name = "mail";
        static_configs = [
          {
            targets = [
              "glesys.ahbk:${toString postfix.port}"
              "glesys.ahbk:${toString dovecot.port}"
            ];
          }
        ];
      }
      {
        job_name = "backup";
        static_configs = [
          {
            targets = [
              "glesys.ahbk:${toString restic.port}"
              "stationary.ahbk:${toString restic.port}"
              "laptop.ahbk:${toString restic.port}"
            ];
          }
        ];
      }
    ];

  };

  services.invoiceplane = {
    webserver = "nginx";
    sites."invoiceplane.ahbk" = {
      enable = true;
      settings = {
        DISABLE_SETUP = true;
      };
    };
  };

  services.kresd = {
    enable = true;
    listenPlain = [ "10.0.0.1:53" ];
    extraConfig = ''
      modules = { 'hints > iterate' }
      hints['invoiceplane.ahbk'] = '10.0.0.1'
      hints['stationary.ahbk'] = '10.0.0.1'
      hints['glesys.ahbk'] = '10.0.0.3'
      hints['laptop.ahbk'] = '10.0.0.2'
      hints['phone.ahbk'] = '10.0.0.4'
      hints['backup.ahbk'] = '10.0.0.1'
    '';
  };

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    firewall = {
      interfaces.wg0 = {
        allowedTCPPortRanges = [
          {
            from = 9000;
            to = 9999;
          }
        ];
      };
      logRefusedConnections = false;
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };

  systemd.network = {
    enable = true;
    networks."10-enp3s0" = {
      matchConfig.Name = "enp3s0";
      networkConfig.DHCP = "ipv4";
    };
  };

  my-nixos = with users; {
    users = {
      inherit alex frans backup;
    };
    shell.alex.enable = true;
    hm.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = true;
      mysql = true;
    };

    glesys.updaterecord = {
      enable = true;
      recordid = "3357682";
      cloudaccount = "cl44748";
      device = "enp3s0";
    };

    fail2ban = {
      enable = true;
      ignoreIP = [
        "10.0.0.0/24"
        "ahbk.se"
        "stationary.ahbk.se"
        "shadowserver.org"
      ];
    };

    wireguard.wg0.enable = true;

    sendmail.alex.enable = true;

    nginx = {
      enable = true;
      email = alex.email;
    };

    wordpress.sites."test.esse.nu" = sites."test.esse.nu";
  };
}
