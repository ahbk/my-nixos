{ pkgs, config, lib, lib', ... }:
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
      hostPrefix = mkOption {
        default = "";
        type = types.str;
      };
    };

  };

  wpPhp = pkgs.php.withExtensions ({ enabled, ... }: enabled ++ [ pkgs.phpExtensions.imagick ]);


in {
  options = {
    ahbk.wordpress = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = {};
        description = mdDoc "Specification of one or more wordpress sites to serve";
      };
    };
  };

  config = mkIf (eachSite != {}) {

    environment = {
      systemPackages = with pkgs; [
        wpPhp
        unzip
      ];
    };

    users = lib'.mergeAttrs (hostname: cfg: {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = {};
    }) eachSite;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (hostname: cfg: [
      "d '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
      "Z '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
      "A '${stateDir hostname}' - - - - u:nginx:rX"
    ]) eachSite);

    services.nginx.virtualHosts = lib'.mergeAttrs (hostname: cfg: let
      finalHostname = if cfg.hostPrefix != "" then "${cfg.hostPrefix}.${hostname}" else hostname;
    in {
      ${hostname}.extraConfig = if (hostname == finalHostname) then "" else ''
        return 301 $scheme://${finalHostname}$request_uri;
      '';

      ${finalHostname} = {
        serverName = finalHostname;
        root = stateDir hostname;
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
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

              location ~ /\.ht {
                deny all;
              }
            '';
          };
        };
      };
    }) eachSite;

    ahbk.mysql = mapAttrs (hostname: cfg: { ensure = true; }) eachSite;

    services.phpfpm.pools = mapAttrs (hostname: cfg: {
      user = hostname;
      group = hostname;
      phpPackage = myPhp;
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
