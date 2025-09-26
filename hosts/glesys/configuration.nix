{
  sites,
  ids,
  users,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    #../../modules/facter.nix
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/77e2add1-dbfd-4f79-aeb9-0f9703ea3f7b";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking = {
    useDHCP = false;
    firewall = {
      logRefusedConnections = false;
    };
  };

  systemd.network = {
    enable = true;
    networks."01-ens1" = {
      matchConfig.Name = "ens1";
      networkConfig.DHCP = "yes";
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];

  services.nginx.virtualHosts."admin.sverigesval.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/".return = "301 https://nc.kompismoln.se$request_uri";
  };

  my-nixos = {
    users.admin = users.admin;
    users.alex = users.alex;
    sysadm.rescueMode = true;
    ssh.enable = true;
    sops.enable = true;
    #facter.enable = true;

    locksmith = {
      enable = true;
      luksDevice = "/dev/null";
    };

    wireguard.wg0.enable = true;

    tls-certs = [ "km" ];

    #fail2ban = {
    #  enable = true;
    #  ignoreIP = [
    #    "10.0.0.0/24"
    #    "ahbk.se"
    #    "stationary.ahbk.se"
    #    "shadowserver.org"
    #  ];
    #};

    backup.km = {
      enable = true;
      target = "backup.km";
    };

    mobilizon.sites."klimatkalendern1" = {
      enable = true;
      hostname = "klimatkalendern.nu";
      appname = "klimatkalendern1";
      www = "yes";
      port = ids.klimatkalendern.port;
      uid = ids.klimatkalendern.uid;
    };

    nextcloud-rolf.sites."sverigesval-sync" = {
      enable = true;
      siteRoot = "/var/lib/nextcloud-kompismoln/nextcloud/data/rolf/files/+pub/_site";
      sourceRoot = "/var/lib/nextcloud-kompismoln/nextcloud/data/rolf/files/+pub";
      hostname = "sverigesval.org";
      username = "nextcloud-kompismoln";
      subnet = false;
      ssl = true;
    };

    nextcloud.sites."nextcloud-kompismoln" = {
      enable = true;
      hostname = "nc.kompismoln.se";
      ssl = true;
      subnet = false;
      port = 2007;
      uid = 978;
      collaboraHost = "collabora.ahbk.se";
      mounts = {
        #alex = "stationary.km:/mnt/t1/alex";
        #johanna = "stationary.km:/mnt/t1/johanna";
        #chris = "stationary.km:/mnt/t1/chris";
        #john = "stationary.km:/mnt/t1/john";
        #petra = "stationary.ahbk:/mnt/t1/petra";
        #rigmor = "stationary.ahbk:/mnt/t1/rigmor";
      };
    };

    collabora = {
      enable = true;
      subnet = false;
      host = "collabora.ahbk.se";
      allowedHosts = [ ];
    };

    nginx = {
      enable = true;
      email = users.alex.email;
    };

    mailserver = {
      enable = true;
      domain = "ahbk.se";
      users = {
        admin = { };
        alex = { };
      };
      domains = {
        "ahbk.se".mailbox = true;
        "klimatkalendern.nu".mailbox = false;
      };
    };

    django-svelte.sites."chatddx" = sites."chatddx";
    django.sites."chatddx" = {
      packagename = "chatddx_backend";
      celery = {
        enable = true;
        port = 2008;
      };
      locationProxy = "/admin";
    };

    django-react.sites."sysctl-user-portal" = sites."sysctl-user-portal";
    django.sites."sysctl-user-portal".locationProxy = "~ ^/(api|admin)";

    wordpress.sites."esse" = sites."esse";
  };
}
