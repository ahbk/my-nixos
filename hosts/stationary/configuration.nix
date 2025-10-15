{
  imports = [
    ../../modules/glesys-updaterecord.nix
  ];

  my-nixos = {
    sysadm.rescueMode = true;

    dns-hints = {
      enable = true;
      subnet = "wg1";
    };

    glesys.updaterecord = {
      enable = true;
      recordid = "3357682";
      cloudaccount = "cl44748";
      device = "enp3s0";
    };

    mobilizon.sites."klimatkalendern-dev" = {
      enable = true;
      www = "no";
      hostname = "klimatkalendern-dev.kompismoln.se";
      appname = "klimatkalendern-dev";
    };
  };

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

}
