{ config
, host
, inputs
, pkgs
, lib
, ...
}:

with lib;

let
  hosts = import ../hosts.nix;
  users = import ../users.nix;
  sites = import ../sites.nix { inherit inputs config; };
  pkgs' = import ../packages/all.nix { inherit pkgs; };
in {
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  services.netdata.enable = true;

  services.nginx.virtualHosts."10.0.0.1".locations."/netdata/" = {
    proxyPass = "http://localhost:19999/";
  };

  ahbk = with users; {
    user = { inherit frans backup; };
    shell.frans.enable = true;
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

    wg-server = {
      enable = true;
      host = host.name;
      address = "10.0.0.1/24";
      peers = filterAttrs (host: cfg: builtins.hasAttr "wgKey" cfg) hosts;
    };

    nginx = {
      enable = true;
      email = frans.email;
    };

    wordpress.sites."test.esse.nu" = sites.wordpress.sites."test.esse.nu";

    odoo = {
      enable = true;
      package = pkgs'.odoo;
      domain = "10.0.0.1";
      settings = {
        options = {
          db_user = "odoo";
          db_name = "odoo";
        };
      };
    };
  };
}
