{ host
, inputs
, lib
, ...
}:

with lib;

let
  users = import ../users.nix;
  hosts = import ../hosts.nix;
  sites = (import ../sites.nix) {
    inherit inputs;
    system = "x86_64-linux";
  };
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

    wg-server = {
      enable = true;
      host = host.name;
      address = "${host.address}/24";
      peers = filterAttrs (host: cfg: builtins.hasAttr "wgKey" cfg) hosts;
    };

    nginx = {
      enable = true;
      email = frans.email;
    };

    mailServer.enable = true;

    chatddx = sites.chatddx;
    sverigesval = sites.sverigesval;
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
