{ inputs
, lib
, ...
}:

with lib;

let
  users = import ../users.nix;
  sites = import ../sites.nix {
    inherit inputs;
    system = "x86_64-linux";
  };
in {
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  services.netdata.enable = true;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.nginx.virtualHosts."stationary.ahbk".locations."/netdata/" = {
    proxyPass = "http://localhost:19999/";
  };

  services.invoiceplane = {
    webserver = "nginx";
    sites."invoiceplane.ahbk" = {
      enable = true;
      settings = {
        DISABLE_SETUP = true;
      };
    };
  };

  services.kresd = {
    enable = true;
    listenPlain = [
      "10.0.0.1:53"
    ];
    extraConfig = ''
    modules = { 'hints > iterate' }
    hints['invoiceplane.ahbk'] = '10.0.0.1'
    hints['stationary.ahbk'] = '10.0.0.1'
    hints['glesys.ahbk'] = '10.0.0.3'
    hints['laptop.ahbk'] = '10.0.0.2'
    hints['phone.ahbk'] = '10.0.0.4'
    hints['backup.ahbk'] = '10.0.0.1'
    '';
  };

  networking.firewall.interfaces.wg0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    interfaces.enp3s0.useDHCP = true;
  };

  my-nixos = with users; {
    user = { inherit frans backup; };
    shell.frans.enable = true;
    hm.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = true;
      mysql = true;
      userAsTopDomain = false;
    };

    glesys.updaterecord = {
      enable = true;
      recordid = "3357682";
      cloudaccount = "cl44748";
      device = "enp3s0";
    };

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = frans.email;
    };

    wordpress.sites."test.esse.nu" = sites.wordpress.sites."test.esse.nu";

  };
}
