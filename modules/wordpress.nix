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
      www = mkOption {
        default = false;
        type = types.bool;
      };
      basicAuth = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
    };
  };

  wpPhp = pkgs.php.buildEnv {
    extensions = { enabled, all }: with all; enabled ++ [ imagick ];
    extraConfig = "memory_limit=256M";
  };

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
      serverName = if cfg.www then "www.${hostname}" else hostname;
      serverNameRedirect = if cfg.www then hostname else "www.${hostname}";
    in {
      ${serverNameRedirect} = {
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        extraConfig = ''
          return 301 $scheme://${serverName}$request_uri;
        '';
      };

      ${serverName} = {
        inherit serverName;
        root = stateDir hostname;
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        extraConfig = ''
          index index.php;
        '';
        locations = {
          "/" = {
            basicAuth = mkIf (cfg.basicAuth != {}) cfg.basicAuth;
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
      phpPackage = wpPhp;
      phpOptions = ''
        upload_max_filesize = 16M;
        post_max_size = 16M;
        error_reporting = E_ALL;
        display_errors = Off;
        log_errors = On;
        error_log = ${stateDir hostname}/error.log;
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
