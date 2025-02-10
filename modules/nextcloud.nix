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
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.nextcloud;
  webserver = config.services.nginx;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/nextcloud";

  siteOpts = {
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
      user = mkOption {
        description = "Username for app owner";
        type = types.str;
      };
      uid = mkOption {
        description = "Userid for app owner";
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

    users = lib'.mergeAttrs (hostname: cfg: {
      users.${cfg.user} = {
        name = cfg.user;
        uid = cfg.uid;
        isSystemUser = true;
        group = cfg.user;
      };
      groups.${cfg.user} = {
        name = cfg.user;
        gid = cfg.uid;
        members = [
          cfg.user
          webserver.user
        ];
      };
    }) eachSite;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (hostname: cfg: [
        "d '${stateDir hostname}' 0750 ${cfg.user} ${cfg.user} - -"
        "Z '${stateDir hostname}' 0750 ${cfg.user} ${cfg.user} - -"
      ]) eachSite
    );

    age.secrets = mapAttrs' (
      hostname: cfg:
      (nameValuePair "${hostname}-nextcloud" {
        file = ../secrets/nextcloud-pass-${hostname}.age;
        owner = cfg.user;
        group = cfg.user;
      })
    ) eachSite;

    my-nixos.postgresql = mapAttrs (hostname: cfg: {
      ensure = true;
      name = cfg.user;
    }) eachSite;

    services.restic.backups.local.paths = flatten (
      mapAttrsToList (hostname: cfg: [ (stateDir hostname) ]) eachSite
    );

    systemd.services = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-pgsql-dump" = {
        description = "dump a snapshot of the postgresql database";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.postgresql}/bin/pg_dump -U ${cfg.user} ${cfg.user} > ${stateDir hostname}/dbdump.sql'";
          User = cfg.user;
          Group = cfg.user;
        };
      };

      "${hostname}-pgsql-restore" = {
        description = "restore postgresql database from snapshot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.postgresql}/bin/psql -U ${cfg.user} ${cfg.user} < ${stateDir hostname}/dbdump.sql'";
          User = cfg.user;
          Group = cfg.user;
        };
      };
    }) eachSite;

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: {
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
    }) eachSite;

    containers = mapAttrs' (
      hostname: cfg:
      (nameValuePair "${cfg.user}-nextcloud" {
        autoStart = true;

        bindMounts = {
          "/var/lib/nextcloud/" = {
            isReadOnly = false;
            hostPath = stateDir hostname;
          };
          "/run/secrets/nextcloud-pass" = {
            isReadOnly = true;
            hostPath = config.age.secrets."${hostname}-nextcloud".path;
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

          services.nextcloud = {
            enable = true;
            hostName = "localhost";
            package = pkgs.nextcloud30;
            settings = {
              trusted_domains = [ hostname ];
            };
            config = {
              dbtype = "pgsql";
              dbhost = "localhost";
              dbpassFile = "/run/secrets/nextcloud-pass";
              dbuser = cfg.user;
              dbname = cfg.user;
              adminpassFile = "/run/secrets/nextcloud-pass";
            };
          };
        };
      })
    ) eachSite;
  };
}
