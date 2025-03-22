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
      hints['lenovo.ahbk'] = '10.0.0.7'
      hints['phone.ahbk'] = '10.0.0.4'
      hints['backup.ahbk'] = '10.0.0.1'
      hints['nextcloud.ahbk'] = '10.0.0.1'
      hints['collabora.ahbk'] = '10.0.0.1'
    '';
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

  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/t1/alex 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/johanna 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/chris 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/media 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
    '';
  };

  users.users.nextcloud-kompismoln = {
    uid = 978;
    isSystemUser = true;
    group = "nextcloud-kompismoln";
  };
  users.groups.nextcloud-kompismoln.gid = 978;

  users.users.jellyfin = {
    uid = 970;
    isSystemUser = true;
    group = "jellyfin";
  };
  users.groups.jellyfin.gid = 970;

  my-nixos = {
    users = with users; {
      inherit admin alex;
    };

    shell.alex.enable = true;
    hm.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = true;
      mysql = true;
    };

    ahbk-cert.enable = true;

    backup.local = {
      enable = true;
      target = "backup.ahbk";
      server = true;
    };

    monitor.enable = true;

    nextcloud.sites."nextcloud-ahbk" = {
      enable = true;
      hostname = "nextcloud.ahbk.se";
      collaboraHost = "collabora.stationary.ahbk.se";
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

    wordpress.sites."esse_test" = (import ../sites.nix)."esse_test";
  };
}
