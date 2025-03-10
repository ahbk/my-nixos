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
    mkForce
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

    age.secrets = mapAttrs' (
      name: cfg:
      (nameValuePair "${cfg.appname}-root" {
        file = ../secrets/${cfg.appname}-root.age;
        owner = cfg.appname;
        group = cfg.appname;
      })
    ) eachSite;

    my-nixos.postgresql = mapAttrs (name: cfg: {
      ensure = true;
      name = cfg.appname;
    }) eachSite;

    services.restic.backups.local.paths = flatten (
      mapAttrsToList (name: cfg: [ (stateDir cfg.appname) ]) eachSite
    );

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
          Unit = "${cfg.appname}-pgsql-dump";
        };
      };
    }) eachSite;

    services.nginx.virtualHosts = mapAttrs' (
      name: cfg:
      nameValuePair cfg.hostname {
        forceSSL = cfg.ssl;
        sslCertificate = mkIf cfg.subnet config.age.secrets.ahbk-cert.path;
        sslCertificateKey = mkIf cfg.subnet config.age.secrets.ahbk-cert-key.path;
        enableACME = !cfg.subnet;

        locations = {
          "/" = {
            proxyPass = "http://localhost:${toString cfg.port}";
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
          "/run/secrets/nextcloud-root" = {
            isReadOnly = true;
            hostPath = config.age.secrets."${cfg.appname}-root".path;
          };
        };

        config = {
          system.stateVersion = config.system.stateVersion;

          users.users.nextcloud.uid = cfg.uid;
          users.groups.nextcloud.gid = cfg.uid;

          services.nginx.virtualHosts.localhost = {
            listen = [
              {
                addr = "127.0.0.1";
                port = cfg.port;
                ssl = false;
              }
            ];
          };

          services.redis.servers.nextcloud = {
            unixSocketPerm = 666;
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
            hostName = "localhost";
            package = pkgs.nextcloud30;
            settings = {
              trusted_domains = [ cfg.hostname ];
              default_phone_region = "SE";
              overwrite_protocol = "https";
            };
            phpOptions = {
              memory_limit = mkForce "2048M";
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
              dbpassFile = "/run/secrets/nextcloud-root";
              dbuser = cfg.appname;
              dbname = cfg.appname;
              adminpassFile = "/run/secrets/nextcloud-root";
            };
          };
        };
      })
    ) eachSite;
  };
}
