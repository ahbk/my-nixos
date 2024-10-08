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

  my-nixos = with users; {
    users = {
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
    ide.alex = {
      enable = true;
      postgresql = false;
      mysql = false;
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

    backup."backup.ahbk".enable = true;

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = alex.email;
    };

    monitor = {
      enable = true;
      config = ''
         set alert ${alex.email}
         set daemon 120 with start delay 60
         set mailserver
             localhost
        set httpd
            port 2812
            use address 10.0.0.3
            allow 10.0.0.0/24
      '';
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
        "esse.nu".mailbox = false;
      };
    };

    django-svelte.sites."chatddx.com" = sites."chatddx.com";
    django.sites."chatddx.com".locationProxy = "/admin";

    django-react.sites."sysctl-user-portal.curetheweb.se" = sites."sysctl-user-portal.curetheweb.se";
    django.sites."sysctl-user-portal.curetheweb.se".locationProxy = "~ ^/(api|admin)";

    fastapi-svelte.sites."sverigesval.org" = sites."sverigesval.org";
    wordpress.sites."esse.nu" = sites."esse.nu";
  };
}
