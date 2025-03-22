{ inputs, pkgs, ... }:
let
  users = import ../users.nix;
  sites = import ../sites.nix;
in
{

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

    root = "/var/lib/kompismoln";
    locations."/" = {
      index = "index.html";
      tryFiles = "$uri $uri/ /404.html";
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
    device = "stationary.ahbk:/mnt/t1/media";
    fsType = "nfs";
  };

  my-nixos = {
    users = with users; {
      inherit
        admin
        alex
        backup
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

    backup.local = {
      enable = true;
      target = "backup.ahbk";
    };

    mobilizon.sites."klimatkalendern" = {
      enable = true;
      hostname = "klimatkalendern.kompismoln.se";
      appname = "klimatkalendern";
      port = 2009;
      uid = 974;
      ssl = true;
      subnet = false;
      containerConf = inputs.klimatkalendern.nixosModules.mobilizon;
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
        alex = "stationary.ahbk:/mnt/t1/alex";
        johanna = "stationary.ahbk:/mnt/t1/johanna";
        chris = "stationary.ahbk:/mnt/t1/chris";
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
