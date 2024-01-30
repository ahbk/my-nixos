{ pkgs, config, lib, ... }: {

  options.wordpress = with lib; {

    enable = mkOption {
      type = types.bool;
      default = false;
    };

    ssl = mkOption {
      type = types.bool;
      default = false;
    };

    www = mkOption {
      type = types.bool;
      default = false;
    };

    host = mkOption {
      type = types.str;
      default = "wp.local";
    };
  };

  config = with config.wordpress; lib.mkIf enable {

    environment = {
      systemPackages = with pkgs; [
        php
        unzip
      ];
    };

    users = {
      users.${host} = {
        isSystemUser = true;
        group = host;
      };
      groups.${host}.name = host;
    };

    services.nginx.virtualHosts = {

      ${host} = {
        forceSSL = ssl;
        enableACME = ssl;
        root = "/var/www/${host}";
        extraConfig = ''
          index index.php index.html index.htm;

          location / {
          try_files $uri $uri/ /index.php?$args;
          }

          location ~ \.php$ {
          include ${pkgs.nginx}/conf/fastcgi.conf;
          fastcgi_intercept_errors on;
          fastcgi_pass unix:/run/phpfpm/wordpress.sock;
          }

          location ~ /\.ht {
          deny all;
          }
        '';
      };
    };

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;

      ensureDatabases = [ host ];
      ensureUsers = [
        {
          name = host;
          ensurePermissions = {
            "\\`${host}\\`.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    systemd.services.${host} = {
      description = "manage ${host}";
      serviceConfig = {
        ExecStartPre = [
          "+-${pkgs.coreutils}/bin/mkdir -p /var/www/${host}"
          "+${pkgs.coreutils}/bin/chown ${host}:${host} /var/www/${host}"
        ];
        ExecStart = ''${pkgs.coreutils}/bin/touch /var/www/${host}/.keep'';
        User = host;
        Group = host;
      };
      wantedBy = [ "multi-user.target" ];
    };

    services.phpfpm.pools.wordpress = {
      user = host;
      group = host;
      phpOptions = ''
        cgi.fix_pathinfo = 1
      '';
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
      };
    };
  };
}
