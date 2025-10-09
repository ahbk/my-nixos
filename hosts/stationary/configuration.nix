{
  ids,
  users,
  ...
}:
{
  imports = [
    ../../modules/facter.nix
    ../../modules/glesys-updaterecord.nix
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/7790a226-31aa-44e3-abc5-8e96df673c74";
    fsType = "ext4";
  };

  fileSystems."/mnt/t1" = {
    device = "/dev/disk/by-uuid/8ac3ae7c-3cd6-4eb3-9ee3-d9af0ec0d41b";
    fsType = "btrfs";
  };

  fileSystems."/mnt/t2" = {
    device = "/dev/disk/by-uuid/a24d01c5-dbc7-4839-907b-9c6fc49e3996";
    fsType = "ext4";
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/2a419392-c7cc-4c9b-9d38-da36f7c29666"; } ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
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
      /mnt/t1 10.0.0.2(rw,no_root_squash,async)
      /mnt/t1/alex 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/johanna 10.0.0.3(rw,no_root_squash,async) 10.0.0.6(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)

      /mnt/t1/chris 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/john 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/media 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/petra 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
      /mnt/t1/rigmor 10.0.0.3(rw,no_root_squash,async) 10.0.0.7(rw,no_root_squash,async)
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
    users.admin = users.admin;
    sysadm.rescueMode = true;
    ssh.enable = true;
    sops.enable = true;
    facter.enable = true;
    nix.serveStore = true;

    dns-hints = {
      enable = true;
      subnet = "wg1";
    };

    locksmith = {
      enable = true;
      luksDevice = "/dev/null";
    };

    backup-server.enable = true;

    backup.km = {
      enable = true;
      target = "backup.km";
    };

    tls-certs = [ "km" ];

    monitor.enable = false;

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
      ];
    };

    nginx = {
      enable = true;
      email = users.admin.email;
    };

    #wordpress.sites."esse_test" = (import ../../sites.nix)."esse_test";

    mobilizon.sites."klimatkalendern-dev" = {
      enable = true;
      www = "no";
      hostname = "klimatkalendern-dev.kompismoln.se";
      appname = "klimatkalendern-dev";
      port = ids.klimatkalendern-dev.port;
      uid = ids.klimatkalendern-dev.uid;
    };
  };
}
