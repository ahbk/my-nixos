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
    mapAttrs'
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.nextcloud;
  webserver = config.services.nginx;

  eachSite = filterAttrs (name: cfg: cfg.enable) cfg.sites;
  stateDir = appname: "/var/lib/${appname}/nextcloud";

  siteOpts =
    { name, ... }:
    {
      config.appname = mkDefault name;
      options = {
        enable = mkEnableOption "nextcloud on this host.";
        ssl = mkOption {
          description = "Enable HTTPS";
          type = types.bool;
        };
        subnet = mkOption {
          description = "Use self-signed certificates";
          type = types.bool;
        };
        port = mkOption {
          description = "Port to serve on";
          type = types.port;
        };
        hostname = mkOption {
          description = "Namespace identifying the service externally on the network.";
          type = types.str;
        };
        appname = mkOption {
          description = "Namespace identifying the app on the system (user, logging, database, paths etc.)";
          type = types.str;
        };
        uid = mkOption {
          description = "Userid is required to map user in container";
          type = types.int;
        };
        collaboraHost = mkOption {
          description = "The hostname of the collabora host";
          type = types.str;
        };
        mounts = mkOption {
          description = "Users with external storage";
          type = types.attrsOf types.str;
          default = { };
        };
      };
    };
in
{
  options = {
    my-nixos.nextcloud = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = { };
        description = "Specification of one or more nextcloud sites to serve";
      };
    };
  };

  config = mkIf (eachSite != { }) {

    fileSystems = lib'.mergeAttrs (
      name: cfg:
      mapAttrs' (
        name: device:
        nameValuePair "${stateDir cfg.appname}/data/${name}" {
          inherit device;
          fsType = "nfs";
        }
      ) cfg.mounts
    ) eachSite;

    users = lib'.mergeAttrs (name: cfg: {
      users.${cfg.appname} = {
        name = cfg.appname;
        uid = cfg.uid;
        isSystemUser = true;
        group = cfg.appname;
      };
      groups.${cfg.appname} = {
        name = cfg.appname;
        gid = cfg.uid;
        members = [
          cfg.appname
          webserver.user
        ];
      };
    }) eachSite;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (name: cfg: [
        "d '${stateDir cfg.appname}' 0750 ${cfg.appname} ${cfg.appname} - -"
        "Z '${stateDir cfg.appname}' 0750 ${cfg.appname} ${cfg.appname} - -"
      ]) eachSite
    );

    sops.secrets = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}/secret-key" = {
        sopsFile = ../enc/service-${cfg.appname}.yaml;
        owner = cfg.appname;
        group = cfg.appname;
      };
    }) eachSite;

    my-nixos.postgresql = mapAttrs (name: cfg: {
      ensure = true;
      name = cfg.appname;
    }) eachSite;

    systemd.services = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}-pgsql-dump" = {
        description = "dump a snapshot of the postgresql database";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.postgresql}/bin/pg_dump -U ${cfg.appname} ${cfg.appname} > ${stateDir cfg.appname}/dbdump.sql'";
          User = cfg.appname;
          Group = cfg.appname;
        };
      };

      "${cfg.appname}-pgsql-restore" = {
        description = "restore postgresql database from snapshot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.postgresql}/bin/psql -U ${cfg.appname} ${cfg.appname} < ${stateDir cfg.appname}/dbdump.sql'";
          User = cfg.appname;
          Group = cfg.appname;
        };
      };
    }) eachSite;

    systemd.timers = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}-pgsql-dump" = {
        description = "scheduled database dump";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Unit = "${cfg.appname}-pgsql-dump.service";
        };
      };
    }) eachSite;

    services.nginx.virtualHosts = mapAttrs' (
      name: cfg:
      nameValuePair cfg.hostname {
        forceSSL = cfg.ssl;
        sslCertificate = mkIf cfg.subnet ../public-keys/domain-km-tls-cert.pem;
        sslCertificateKey = mkIf cfg.subnet config.sops.secrets."km/tls-cert".path;
        enableACME = !cfg.subnet;
        extraConfig = ''
          client_max_body_size 1G;
        '';

        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
          };
          "/.well-known/carddav" = {
            return = "301 $scheme://$host/remote.php/dav";
          };

          "/.well-known/caldav" = {
            return = "301 $scheme://$host/remote.php/dav";
          };
        };
      }
    ) eachSite;

    containers = mapAttrs' (
      name: cfg:
      (nameValuePair cfg.appname {
        autoStart = true;

        bindMounts = {
          ${config.services.nextcloud.home} = {
            isReadOnly = false;
            hostPath = stateDir cfg.appname;
          };
          "/run/secrets/db-password" = {
            isReadOnly = true;
            hostPath = config.sops.secrets."${cfg.appname}/secret-key".path;
          };
          "/run/secrets/admin-password" = {
            isReadOnly = true;
            hostPath = config.sops.secrets."${cfg.appname}/secret-key".path;
          };
        };

        config = {
          system.stateVersion = config.system.stateVersion;

          users.users.nextcloud.uid = cfg.uid;
          users.groups.nextcloud.gid = cfg.uid;

          services.nginx = {
            virtualHosts.localhost = {
              extraConfig = ''
                set_real_ip_from 127.0.0.1/32;
                real_ip_header X-Forwarded-For;
                real_ip_recursive on;
              '';
              listen = [
                {
                  addr = "127.0.0.1";
                  port = cfg.port;
                  ssl = false;
                }
              ];
            };
          };

          systemd.services.nextcloud-setup = {
            after = [
              "redis-nextcloud.service"
            ];
            requires = [
              "redis-nextcloud.service"
            ];
          };

          services.nextcloud = {
            enable = true;
            https = true;
            hostName = "localhost";
            package = pkgs.nextcloud31;
            appstoreEnable = true;
            maxUploadSize = "1G";
            extraApps = {
              inherit (pkgs.nextcloud30Packages.apps) calendar;
            };
            settings = {
              trusted_proxies = [
                "127.0.0.1"
              ];
              trusted_domains = [
                cfg.hostname
                cfg.collaboraHost
              ];
              default_phone_region = "SE";
              overwriteprotocol = "https";
              forwarded_for_headers = [ "HTTP_X_FORWARDED_FOR" ];
              "simpleSignUpLink.shown" = false;
            };
            phpOptions = {
              "opcache.interned_strings_buffer" = 23;
            };
            configureRedis = true;
            caching = {
              redis = true;
              memcached = true;
            };
            config = {
              dbtype = "pgsql";
              dbhost = "localhost";
              dbpassFile = "/run/secrets/db-password";
              dbuser = cfg.appname;
              dbname = cfg.appname;
              adminpassFile = "/run/secrets/admin-password";
            };
          };
        };
      })
    ) eachSite;
  };
}
