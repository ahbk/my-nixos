{
  inputs,
  pkgs,
  ids,
  users,
  ...
}:
let
  sites = import ../../sites.nix;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

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

  security.sudo.extraRules = [
    {
      users = [
        "ludvig"
        "alex"
      ];
      runAs = "ALL:mobilizon";
      commands = [ "${pkgs.postgresql}/bin/psql" ];
    }
    {
      users = [
        "ludvig"
        "alex"
      ];
      commands = [
        "${pkgs.systemd}/bin/systemctl restart mobilizon.service"
        "${pkgs.systemd}/bin/systemctl stop mobilizon.service"
        "${pkgs.systemd}/bin/systemctl start mobilizon.service"
      ];
    }
  ];

  services.nginx.virtualHosts."kompismoln.se" = {
    forceSSL = true;
    enableACME = true;

    root = inputs.kompismoln-site.packages."x86_64-linux".default;

    locations."= /" = {
      tryFiles = "/index.html =404";
    };

    locations."/" = {
      tryFiles = "$uri $uri.html =404";
    };
  };

  users.users.jellyfin = {
    uid = 970;
    isSystemUser = true;
    group = "jellyfin";
  };
  users.groups.jellyfin.gid = 970;
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  fileSystems."/var/lib/jellyfin/media" = {
    device = "stationary.km:/mnt/t1/media";
    fsType = "nfs";
  };

  my-nixos = {
    users = with users; {
      inherit
        admin
        alex
        ludvig
        ;
    };
    shell.alex.enable = true;
    hm.alex.enable = true;

    shell.ludvig.enable = true;
    hm.ludvig.enable = true;

    fail2ban = {
      enable = true;
      ignoreIP = [
        "10.0.0.0/24"
        "ahbk.se"
        "stationary.ahbk.se"
        "shadowserver.org"
      ];
    };

    backup.km = {
      enable = true;
      target = "backup.ahbk";
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
        alex = "stationary.km:/mnt/t1/alex";
        johanna = "stationary.km:/mnt/t1/johanna";
        chris = "stationary.km:/mnt/t1/chris";
        john = "stationary.km:/mnt/t1/john";
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

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = users.alex.email;
    };

    mailserver = {
      enable = true;
      users = {
        "admin" = { };
        "alex" = { };
      };
      domains = {
        "ahbk.se".mailbox = true;
        "chatddx.com".mailbox = true;
        "sverigesval.org".mailbox = true;
        "kompismoln.se".mailbox = true;
        "esse.nu".mailbox = false;
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
