{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.ahbk.wordpress;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/wordpress";

  siteOpts = { lib, name, config, ... }: {
    options = {
      enable = mkOption {
        default = true;
        type = types.bool;
      };
      ssl = mkOption {
        type = types.bool;
      };
    };

  };

in {
  options = {
    ahbk.wordpress = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = {};
        description = mdDoc "Specification of one or more Django sites to serve";
      };
    };
  };

  config = mkIf (eachSite != {}) {

    environment = {
      systemPackages = with pkgs; [
        php
        unzip
      ];
    };

    users = foldlAttrs (acc: hostname: cfg: (recursiveUpdate acc {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = {};
    })) {} eachSite;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (hostname: cfg: [
      "d '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
      "Z '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
    ]) eachSite);

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: {
      serverName = hostname;
      root = stateDir hostname;
      forceSSL = ssl;
      enableACME = ssl;
      extraConfig = ''
          index index.php;
      '';
      locations = {
        "/" = {
          priority = 200;
          extraConfig = ''
            try_files $uri $uri/ /index.php?$args;
          '';
        };

        "~ \\.php$" = {
          priority = 500;
          extraConfig = ''
            include ${pkgs.nginx}/conf/fastcgi.conf;
            fastcgi_intercept_errors on;
            fastcgi_pass unix:${config.services.phpfpm.pools.${hostname}.socket};
            }

            location ~ /\.ht {
            deny all;
            }
          '';
        };
      };
    }) eachSite;

    ahbk.mysql = mapAttrs (hostname: cfg: { ensure = true; });

    services.phpfpm.pools = mapAttrs (hostname: cfg: {
      user = hostname;
      group = hostname;
      phpOptions = ''
        cgi.fix_pathinfo = {1
      '';
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
    }) eachSite;
  };
}
