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
    user = {
      inherit alex frans backup;
    };
    shell.frans.enable = true;
    hm.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = false;
      mysql = false;
    };

    fail2ban.enable = true;

    backup."backup.ahbk".enable = true;

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = frans.email;
    };

    mailserver.enable = true;

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
