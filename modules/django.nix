{
  config,
  host,
  inputs,
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
    optionalAttrs
    types
    ;

  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.django;

  eachSite = filterAttrs (name: cfg: cfg.enable) cfg.sites;
  eachCelery = filterAttrs (name: cfg: cfg.celery.enable) eachSite;

  stateDir = appname: "/var/lib/${appname}/django";

  siteOpts =
    { name, ... }:
    {
      config.appname = mkDefault name;
      options = {
        enable = mkEnableOption "Django app";
        port = mkOption {
          description = "Listening port.";
          example = 8000;
          type = types.port;
        };
        ssl = mkOption {
          description = "Whether to enable SSL (https) support.";
          type = types.bool;
        };
        hostname = mkOption {
          description = "Namespace identifying the service externally on the network.";
          type = types.str;
        };
        appname = mkOption {
          description = "Namespace identifying the app on the system (user, logging, database, paths etc.)";
          type = types.str;
        };
        packagename = mkOption {
          description = "The python name of the django application";
          type = types.str;
          default = "app";
        };
        locationStatic = mkOption {
          description = "Location pattern for static files, empty string -> no static";
          type = types.str;
          default = "/static/";
        };
        locationProxy = mkOption {
          description = "Location pattern for proxy to django, empty string -> no proxy";
          type = types.str;
          example = "~ ^/(api|admin)";
          default = "/";
        };
        celery = {
          enable = mkEnableOption "Celery";
          port = mkOption {
            description = "Listening port for message broker.";
            type = types.nullOr types.port;
            default = null;
          };
        };
      };
    };

  djangoPkgs = appname: inputs.${appname}.djangoPkgs.${host.system};

  envs = mapAttrs (
    name: cfg:
    (lib'.mkEnv cfg.appname (
      {
        DB_NAME = cfg.appname;
        DB_USER = cfg.appname;
        DB_HOST = "/run/postgresql";
        DEBUG = "false";
        DJANGO_SETTINGS_MODULE = "${cfg.packagename}.settings";
        HOST = cfg.hostname;
        LOG_LEVEL = "WARNING";
        SCHEME = if cfg.ssl then "https" else "http";
        SECRET_KEY_FILE = config.age.secrets."${cfg.appname}/secret-key".path;
        STATE_DIR = stateDir cfg.appname;
      }
      // (optionalAttrs cfg.celery.enable {
        CELERY_BROKER_URL = "redis://127.0.0.1:${toString cfg.celery.port}/0";
        FLOWER_URL_PREFIX = "/flower";
      })
    ))
  ) eachSite;

  bins = mapAttrs (
    name: cfg:
    ((djangoPkgs cfg.appname).bin.overrideAttrs {
      django_env = envs.${cfg.appname};
      name = "${cfg.appname}-manage";
    })
  ) eachSite;
in
{

  options.my-nixos.django = {
    sites = mkOption {
      type = types.attrsOf (types.submodule siteOpts);
      default = { };
      description = "Definition of per-domain Django apps to serve.";
    };
  };

  config = mkIf (eachSite != { }) {

    environment.systemPackages = mapAttrsToList (name: bin: bin) bins;

    age.secrets = mapAttrs' (
      name: cfg:
      (nameValuePair "${cfg.appname}/secret-key" {
        file = ../secrets/webapp-key-${cfg.appname}.age;
        owner = cfg.appname;
        group = cfg.appname;
      })
    ) eachSite;

    services.redis.servers = mapAttrs (name: cfg: {
      enable = true;
      port = cfg.celery.port;
      settings = {
        syslog-ident = "${cfg.appname}-redis";
      };
    }) eachCelery;

    users = lib'.mergeAttrs (name: cfg: {
      users.${cfg.appname} = {
        isSystemUser = true;
        group = cfg.appname;
      };
      groups.${cfg.appname} = { };
    }) eachSite;

    my-nixos.postgresql = mapAttrs (name: cfg: { ensure = true; }) eachSite;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (name: cfg: [
        "d '${stateDir cfg.appname}' 0750 ${cfg.appname} ${cfg.appname} - -"
        "Z '${stateDir cfg.appname}' 0750 ${cfg.appname} ${cfg.appname} - -"
      ]) eachSite
    );

    services.nginx.virtualHosts = mapAttrs' (
      name: cfg:
      nameValuePair cfg.hostname {
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        locations =
          optionalAttrs (cfg.locationProxy != "") {
            ${cfg.locationProxy} = {
              recommendedProxySettings = true;
              proxyPass = "http://localhost:${toString cfg.port}";
            };
          }
          // optionalAttrs (cfg.locationStatic != "") {
            ${cfg.locationStatic} = {
              alias = "${(djangoPkgs cfg.appname).static}/";
            };
          }
          // optionalAttrs (cfg.celery.enable) {
            "/auth" = {
              recommendedProxySettings = true;
              proxyPass = "http://localhost:${toString cfg.port}";
            };
            "/flower/" = {
              proxyPass = "http://localhost:5555";
              extraConfig = ''
                auth_request /auth/;
              '';
            };
          };
      }
    ) eachSite;

    systemd.services = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}-django" = {
        description = "serve ${cfg.appname}-django";
        serviceConfig = {
          ExecStart = "${(djangoPkgs cfg.appname).app}/bin/gunicorn ${cfg.packagename}.wsgi:application --bind localhost:${toString cfg.port}";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = envs.${cfg.appname};
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-celery" = mkIf cfg.celery.enable {
        description = "start ${cfg.appname}-celery";
        serviceConfig = {
          ExecStart = "${(djangoPkgs cfg.appname).app}/bin/celery -A ${cfg.packagename} worker -l warning";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = envs.${cfg.appname};
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-flower" = mkIf cfg.celery.enable {
        description = "start ${cfg.appname}-flower";
        serviceConfig = {
          ExecStart = "${(djangoPkgs cfg.appname).app}/bin/celery -A ${cfg.packagename} flower --port=5555";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = envs.${cfg.appname};
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-django-migrate" = {
        description = "migrate ${cfg.appname}-django";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${(djangoPkgs cfg.appname).app}/bin/django-admin migrate";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = envs.${cfg.appname};
        };
      };
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
        description = "Scheduled PostgreSQL database dump";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Unit = "${cfg.appname}-pgsql-dump";
        };
      };
    }) eachSite;

    services.restic.backups.local.paths = flatten (
      mapAttrsToList (name: cfg: [ (stateDir cfg.appname) ]) eachSite
    );

    system.activationScripts = mapAttrs (name: cfg: {
      text = ''
        ${pkgs.systemd}/bin/systemctl start ${cfg.appname}-django-migrate
      '';
    }) eachSite;
  };
}
