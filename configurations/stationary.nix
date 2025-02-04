{
  config,
  lib,
  pkgs,
  ...
}:
let
  users = import ../users.nix;
in
{
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

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
      hints['nextcloud.ahbk'] = '10.0.0.1'
      hints['collabora.ahbk'] = '10.0.0.1'
    '';
  };

  my-nixos.ahbk-cert.enable = true;

  age.secrets = {
    nextcloud = {
      file = ../secrets/nextcloud-pass.age;
      owner = "nextcloud";
      group = "nextcloud";
    };
  };

  services.collabora-online = {
    enable = true;
    settings.ssl = rec {
      ca_file_path = cert_file_path;
      cert_file_path = config.age.secrets.ahbk-cert.path;
      key_file_path = config.age.secrets.ahbk-cert-key.path;
    };
    aliasGroups = [ { host = "https://collabora.ahbk:9980"; } ];
  };

  services.nginx.virtualHosts."nextcloud.ahbk" = {
    forceSSL = true;
    sslCertificate = config.age.secrets.ahbk-cert.path;
    sslCertificateKey = config.age.secrets.ahbk-cert-key.path;
  };

  services.nextcloud = {
    enable = true;
    https = true;
    hostName = "nextcloud.ahbk";
    package = pkgs.nextcloud30;
    database.createLocally = true;
    config = {
      dbtype = "pgsql";
      adminpassFile = config.age.secrets.nextcloud.path;
    };
  };

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    firewall = {
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

  my-nixos = {
    users = with users; {
      inherit alex frans;
    };
    shell.alex.enable = true;
    hm.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = true;
      mysql = true;
    };

    backup.local = {
      enable = true;
      target = "backup.ahbk";
      server = true;
    };

    monitor.enable = true;

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
      email = users.alex.email;
    };

    #wordpress.sites."test.esse.nu" = sites."test.esse.nu";
  };
}
