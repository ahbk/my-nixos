{ config
, inputs
, ...
}:

let
  users = import ../users.nix;
  sites = (import ../sites.nix) inputs config;
in

{
  ahbk = with users; {
    user = { inherit alex frans; };
    shell.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = false;
      mysql = false;
      userAsTopDomain = false;
    };

    nginx = {
      enable = true;
      email = frans.email;
    };

    mailServer.enable = true;

    inherit (sites) chatddx sverigesval;
    wordpress.sites."esse.nu" = sites.wordpress.sites."esse.nu";
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
