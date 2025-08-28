{
  config,
  ids,
  lib,
  modulesPath,
  users,
  ...
}:
{
  # facter.reportPath = ./facter.json;
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "uhci_hcd"
    "ehci_pci"
    "ata_piix"
    "xhci_pci"
    "usb_storage"
    "usbhid"
    "floppy"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

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

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.invoiceplane = {
    webserver = "nginx";
    sites."invoiceplane.km" = {
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
      hints['invoiceplane.km'] = '10.0.0.1'
      hints['dev.km'] = '10.0.0.1'
      hints['backup.km'] = '10.0.0.1'
      hints['nextcloud.km'] = '10.0.0.1'
      hints['collabora.km'] = '10.0.0.1'
      hints['stationary.km'] = '10.0.0.1'
      hints['laptop.km'] = '10.0.0.2'
      hints['glesys.km'] = '10.0.0.3'
      hints['phone.km'] = '10.0.0.4'
      hints['helsinki.km'] = '10.0.0.5'
      hints['friday.km'] = '10.0.0.6'
      hints['lenovo.km'] = '10.0.0.7'
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

    tls-certs = [ "km" ];

    backup-server.enable = true;

    backup.km = {
      enable = true;
      target = "backup.km";
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
      ];
    };

    wireguard.wg0.enable = true;

    sendmail.alex.enable = true;

    nginx = {
      enable = true;
      email = users.alex.email;
    };

    wordpress.sites."esse_test" = (import ../../sites.nix)."esse_test";

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
