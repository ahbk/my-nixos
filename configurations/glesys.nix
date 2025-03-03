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

  services.mobilizon = {
    enable = true;
    settings.":mobilizon" = {
      "Mobilizon.Web.Endpoint" = {
        url.host = "mobilizon.kompismoln.se";
        http.port = 4000;
      };
      "Mobilizon.Storage.Repo" = {
      };
      ":instance" = {
        name = "sweclimate";
        hostname = "mobilizon.kompismoln.se";
        email_from = "mobilizon@kompismoln.se";
        email_reply_to = "mobilizon@kompismoln.se";
      };
    };
  };

  my-nixos = {
    users = with users; {
      inherit
        alex
        backup
        frans
        olof
        rolf
        ;
    };
    shell.alex.enable = true;
    hm.alex.enable = true;

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

    nextcloud.sites."admin.sverigesval.org" = {
      enable = true;
      user = "sverigesval-nextcloud";
      ssl = true;
      subnet = false;
      port = 2007;
      uid = 978;
    };

    collabora = {
      enable = true;
      subnet = false;
      host = "collabora.ahbk.se";
      allowedHosts = [ "admin.sverigesval.org" ];
    };

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = users.alex.email;
    };

    mailserver = {
      enable = true;
      users = {
        "alex" = { };
        "frans" = { };
        "olof" = { };
        "rolf" = { };
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

    fastapi-svelte.sites."sverigesval" = sites."sverigesval";
    wordpress.sites."esse.nu" = sites."esse.nu";
  };
}
