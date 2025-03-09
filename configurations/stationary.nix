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
      hints['dev.ahbk'] = '10.0.0.1'
      hints['glesys.ahbk'] = '10.0.0.3'
      hints['laptop.ahbk'] = '10.0.0.2'
      hints['friday.ahbk'] = '10.0.0.6'
      hints['phone.ahbk'] = '10.0.0.4'
      hints['backup.ahbk'] = '10.0.0.1'
      hints['nextcloud.ahbk'] = '10.0.0.1'
      hints['collabora.ahbk'] = '10.0.0.1'
    '';
  };

  users.users.alex.extraGroups = [ "nextcloud-ahbk" ];

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

    ahbk-cert.enable = true;

    nextcloud-rolf.sites."sverigesval-sync" = {
      enable = true;
      siteRoot = "/var/lib/nextcloud-ahbk/nextcloud/data/alex/files/+pub/_site";
      sourceRoot = "/var/lib/nextcloud-ahbk/nextcloud/data/alex/files/+pub";
      hostname = "stationary.ahbk.se";
      username = "nextcloud-ahbk";
      subnet = false;
      ssl = true;
    };

    backup.local = {
      enable = true;
      target = "backup.ahbk";
      server = true;
    };

    monitor.enable = true;

    nextcloud.sites."nextcloud-ahbk" = {
      enable = true;
      hostname = "nextcloud.ahbk.se";
      ssl = true;
      subnet = false;
      port = 2006;
      uid = 981;
    };

    collabora = {
      enable = true;
      subnet = false;
      host = "collabora.stationary.ahbk.se";
      allowedHosts = [ "nextcloud.ahbk.se" ];
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
      email = users.alex.email;
    };

    wordpress.sites."test.esse.nu" = (import ../sites.nix)."test.esse.nu";
  };
}
