{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    flatten
    getExe
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.wordpress;
  webserver = config.services.nginx;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/wordpress";

  siteOpts = {
    options = {
      enable = mkEnableOption "wordpress on this host.";
      ssl = mkOption {
        description = "Enable HTTPS.";
        type = types.bool;
      };
      www = mkOption {
        description = "Prefix the url with www.";
        default = false;
        type = types.bool;
      };
      basicAuth = mkOption {
        description = "Protect the site with basic auth.";
        type = types.attrsOf types.str;
        default = { };
      };
    };
  };

  wpPhp = pkgs.php.buildEnv {
    extensions = { enabled, all }: with all; enabled ++ [ imagick ];
    extraConfig = ''
      memory_limit = 256M
      cgi.fix_pathinfo = 0
    '';
  };
in
{
  options = {
    my-nixos.wordpress = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = { };
        description = "Specification of one or more wordpress sites to serve";
      };
    };
  };

  config = mkIf (eachSite != { }) {

    users = lib'.mergeAttrs (hostname: cfg: {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
        extraGroups = [ webserver.group ];
      };
      groups.${hostname} = { };
    }) eachSite;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (hostname: cfg: [
        "d '${stateDir hostname}' 0750 ${hostname} ${webserver.group} - -"
        "Z '${stateDir hostname}' 0750 ${hostname} ${webserver.group} - -"
      ]) eachSite
    );

    environment.etc."fail2ban/filter.d/phpfpm-probe.local".text = ''
    [Definition]
    failregex = ^.*\[error\].*FastCGI sent in stderr: "Unable to open primary script:.*client: <HOST>.*index\.php.*$
    '';

    services.fail2ban.jails = {
      phpfpm-probe.settings = {
        filter = "phpfpm-probe";
        backend = "systemd";
        maxretry = 5;
        findtime = 600;
      };
    };

    services.nginx.virtualHosts = lib'.mergeAttrs (
      hostname: cfg:
      let
        serverName = if cfg.www then "www.${hostname}" else hostname;
        serverNameRedirect = if cfg.www then hostname else "www.${hostname}";
      in
      {
        ${serverNameRedirect} = {
          forceSSL = cfg.ssl;
          enableACME = cfg.ssl;
          extraConfig = ''
            return 301 $scheme://${serverName}$request_uri;
          '';
        };

        ${serverName} = {
          root = stateDir hostname;
          forceSSL = cfg.ssl;
          enableACME = cfg.ssl;
          basicAuth = mkIf (cfg.basicAuth != { }) cfg.basicAuth;

          extraConfig = ''
            index index.php;
          '';

          locations = {
            "/favicon.ico" = {
              priority = 100;
              extraConfig = ''
                log_not_found off;
                access_log off;
              '';
            };

            "/robots.txt" = {
              priority = 100;
              extraConfig = ''
                allow all;
                log_not_found off;
                access_log off;
              '';
            };

            "/" = {
              priority = 200;
              extraConfig = ''
                try_files $uri $uri/ /index.php?$args;
              '';
            };

            "~ \\.php$" = {
              priority = 300;
              extraConfig = ''
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:${config.services.phpfpm.pools.${hostname}.socket};
                fastcgi_index index.php;
                include ${config.services.nginx.package}/conf/fastcgi.conf;
                fastcgi_intercept_errors on;
                fastcgi_param HTTP_PROXY "";
                fastcgi_buffer_size 16k;
                fastcgi_buffers 4 16k;
              '';
            };

            "~ /\\." = {
              priority = 800;
              extraConfig = ''deny all;'';
            };

            "~* /(?:uploads|files)/.*\\.php$" = {
              priority = 900;
              extraConfig = ''deny all;'';
            };

            "~* \\.(js|css|png|jpg|jpeg|gif|ico)$" = {
              priority = 1000;
              extraConfig = ''
                expires max;
                log_not_found off;
              '';
            };
          };
        };
      }
    ) eachSite;

    my-nixos.mysql = mapAttrs (hostname: cfg: { ensure = true; }) eachSite;

    services.phpfpm.pools = mapAttrs (hostname: cfg: {
      user = hostname;
      group = webserver.group;
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
        "listen.owner" = webserver.user;
        "listen.group" = webserver.group;
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
    }) eachSite;

    systemd.services = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-mysql-dump" = {
        description = "dump a snapshot of the mysql database";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.mariadb}/bin/mysqldump -u ${hostname} ${hostname} > ${stateDir hostname}/dbdump.sql'";
          User = hostname;
          Group = hostname;
        };
      };
      "${hostname}-mysql-restore" = {
        description = "restore mysql database from snapshot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.mariadb}/bin/mysql -u ${hostname} ${hostname} < ${stateDir hostname}/dbdump.sql'";
          User = hostname;
          Group = hostname;
        };
      };
    }) eachSite;

    my-nixos.backup."backup.ahbk".paths = flatten (
      mapAttrsToList (hostname: cfg: [ (stateDir hostname) ]) eachSite
    );

    systemd.timers = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-mysql-dump" = {
        description = "scheduled database dump";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Unit = "${hostname}-mysql-dump";
        };
      };
    }) eachSite;
  };
}
