let
  users = import ../users.nix;
  sites = import ../sites.nix;
in
{
  networking = {
    useDHCP = false;
    interfaces.ens1.useDHCP = true;
    firewall.logRefusedConnections = false;
  };

  my-nixos = with users; {
    users = {
      inherit alex frans backup;
    };
    shell.alex.enable = true;
    hm.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = false;
      mysql = false;
    };

    fail2ban.enable = true;

    backup."backup.ahbk".enable = true;

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = alex.email;
    };

    mailserver = {
      enable = true;
      users = {
        "alex" = { };
        "frans" = { };
      };
      domains = {
        "ahbk.se".relay = true;
        "esse.nu".relay = false;
      };
    };

    django-svelte.sites."chatddx.com" = sites."chatddx.com";
    fastapi-svelte.sites."sverigesval.org" = sites."sverigesval.org";
    wordpress.sites."esse.nu" = sites."esse.nu";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 4096;
    }
  ];
}
