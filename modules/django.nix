{
  config,
  host,
  inputs,
  lib,
  lib',
  pkgs,
  ids,
  ...
}:

let
  inherit (lib)
    filterAttrs
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
          default = true;
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

  envs = mapAttrs (
    name: cfg:
    {
      DB_NAME = "${cfg.appname}-django";
      DB_USER = "${cfg.appname}-django";
      DB_HOST = "/run/postgresql";
      DEBUG = "false";
      DJANGO_SETTINGS_MODULE = "${cfg.packagename}.settings";
      HOST = cfg.hostname;
      LOG_LEVEL = "WARNING";
      SCHEME = if cfg.ssl then "https" else "http";
      SECRET_KEY_FILE = config.sops.secrets."${cfg.appname}-django/secret-key".path;
      STATE_DIR = stateDir cfg.appname;
    }
    // (optionalAttrs cfg.celery.enable {
      CELERY_BROKER_URL = "redis://127.0.0.1:${toString ids."${cfg.appname}-redis".port}/0";
      FLOWER_URL_PREFIX = "/flower";
    })
  ) eachSite;

  bins = mapAttrs (
    name: cfg:
    inputs.${cfg.appname}.lib.${host.system}.mkDjangoManage {
      runtimeEnv = envs.${cfg.appname};
    }
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

    my-nixos.preserve.directories = mapAttrsToList (name: cfg: {
      directory = stateDir cfg.appname;
      how = "symlink";
      user = "${cfg.appname}-django";
      group = "${cfg.appname}-django";
    }) eachSite;

    sops.secrets = mapAttrs' (
      name: cfg:
      nameValuePair "${cfg.appname}-django/secret-key" {
        sopsFile = ../enc/service-${cfg.appname}-django.yaml;
        owner = "${cfg.appname}-django";
        group = "${cfg.appname}-django";
      }
    ) eachSite;

    my-nixos.redis.servers = lib.mapAttrs (name: cfg: {
      enable = true;
    }) eachCelery;

    my-nixos.users = lib.mapAttrs' (
      name: cfg:
      lib.nameValuePair "${cfg.appname}-django" {
        class = "service";
        publicKey = false;
      }
    ) eachSite;

    my-nixos.postgresql = mapAttrs' (
      name: cfg: nameValuePair "${name}-django" { ensure = true; }
    ) eachSite;

    services.nginx.virtualHosts = mapAttrs' (
      name: cfg:
      nameValuePair cfg.hostname {
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        locations =
          optionalAttrs (cfg.locationProxy != "") {
            ${cfg.locationProxy} = {
              recommendedProxySettings = true;
              proxyPass = "http://localhost:${toString ids."${cfg.appname}-django".port}";
            };
          }
          // optionalAttrs (cfg.locationStatic != "") {
            ${cfg.locationStatic} = {
              alias = "${inputs.${cfg.appname}.packages.${host.system}.django-static}/";
            };
          }
          // optionalAttrs (cfg.celery.enable) {
            "/auth" = {
              recommendedProxySettings = true;
              proxyPass = "http://localhost:${toString ids."${cfg.appname}-django".port}";
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
          ExecStart = "${
            inputs.${cfg.appname}.packages.${host.system}.django-app
          }/bin/gunicorn ${cfg.packagename}.wsgi:application --bind localhost:${
            toString ids."${cfg.appname}-django".port
          }";
          User = "${cfg.appname}-django";
          Group = "${cfg.appname}-django";
          Environment = lib'.envToList envs.${cfg.appname};
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-celery" = mkIf cfg.celery.enable {
        description = "start ${cfg.appname}-celery";
        serviceConfig = {
          ExecStart = "${
            inputs.${cfg.appname}.packages.${host.system}.django-app
          }/bin/celery -A ${cfg.packagename} worker -l warning";
          User = "${cfg.appname}-django";
          Group = "${cfg.appname}-django";
          Environment = lib'.envToList envs.${cfg.appname};
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-flower" = mkIf cfg.celery.enable {
        description = "start ${cfg.appname}-flower";
        serviceConfig = {
          ExecStart = "${
            inputs.${cfg.appname}.packages.${host.system}.django-app
          }/bin/celery -A ${cfg.packagename} flower --port=5555";
          User = "${cfg.appname}-django";
          Group = "${cfg.appname}-django";
          Environment = lib'.envToList envs.${cfg.appname};
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-django-migrate" = {
        description = "migrate ${cfg.appname}-django";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${inputs.${cfg.appname}.packages.${host.system}.django-app}/bin/django-admin migrate";
          User = "${cfg.appname}-django";
          Group = "${cfg.appname}-django";
          Environment = lib'.envToList envs.${cfg.appname};
        };
      };
      "${cfg.appname}-pgsql-dump" = {
        description = "dump a snapshot of the postgresql database";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.pgsql-dump}/bin/pgsql-dump ${cfg.appname}-django ${stateDir cfg.appname}";
          User = "${cfg.appname}-django";
          Group = "${cfg.appname}-django";
        };
      };
      "${cfg.appname}-pgsql-restore" = {
        description = "restore postgresql database from snapshot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.pgsql-restore}/bin/pgsql-restore ${cfg.appname}-django ${stateDir cfg.appname}";
          User = "${cfg.appname}-django";
          Group = "${cfg.appname}-django";
        };
      };
    }) eachSite;

    systemd.timers = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}-pgsql-dump" = {
        description = "Scheduled PostgreSQL database dump";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Unit = "${cfg.appname}-pgsql-dump.service";
        };
      };
    }) eachSite;

    # maybe gate this? maybe offer restore as well, probably none though.
    #system.activationScripts = mapAttrs (name: cfg: {
    #  text = ''
    #    ${pkgs.systemd}/bin/systemctl start ${cfg.appname}-django-migrate
    #  '';
    #}) eachSite;
  };
}
