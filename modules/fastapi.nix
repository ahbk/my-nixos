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
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.fastapi;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/fastapi";

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "FastAPI app";
      port = mkOption {
        description = "Listening port.";
        example = 8000;
        type = port;
      };
      ssl = mkOption {
        description = "Whether to enable SSL (https) support.";
        type = bool;
      };
      appname = mkOption {
        description = "Internal namespace";
        type = str;
        default = null;
      };
      hostname = mkOption {
        description = "Network namespace";
        type = str;
        default = null;
      };
    };
  };

  fastapiPkgs = appname: inputs.${appname}.packages.${host.system}.fastapi;

  envs = mapAttrs (
    name: cfg:
    (lib'.mkEnv cfg.appname {
      ALLOW_ORIGINS = "'[\"${if cfg.ssl then "https" else "http"}://${cfg.hostname}\"]'";
      DB_DSN = "postgresql+psycopg2://${cfg.appname}@:5432/${cfg.appname}";
      ENV = "production";
      HOSTNAME = cfg.hostname;
      LOG_LEVEL = "error";
      SECRETS_DIR = builtins.dirOf config.sops.secrets."${cfg.appname}/secret_key".path;
      SSL = if cfg.ssl then "true" else "false";
      STATE_DIR = stateDir cfg.appname;
      ALEMBIC_CONFIG = "${(fastapiPkgs cfg.appname).alembic}/alembic.ini";
    })
  ) eachSite;

  bins = mapAttrs (
    name: cfg:
    ((fastapiPkgs cfg.appname).bin.overrideAttrs {
      env = envs.${cfg.appname};
      name = "${cfg.appname}-manage";
    })
  ) eachSite;
in
{

  options.my-nixos.fastapi = with types; {
    sites = mkOption {
      type = attrsOf (submodule siteOpts);
      default = { };
      description = "Definition of per-domain FastAPI apps to serve.";
    };
  };

  config = mkIf (eachSite != { }) {

    environment.systemPackages = mapAttrsToList (name: bin: bin) bins;

    sops.secrets = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}/secret_key" = {
        owner = cfg.appname;
        group = cfg.appname;
      };
    }) eachSite;

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

    services.nginx.virtualHosts = mapAttrs (name: cfg: {
      serverName = cfg.hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/api" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }) eachSite;

    systemd.services = lib'.mergeAttrs (name: cfg: {
      "${cfg.appname}-fastapi" = {
        description = "serve ${cfg.appname}-fastapi";
        serviceConfig = {
          ExecStart = "${(fastapiPkgs cfg.appname).app}/bin/uvicorn app.main:fastapi --host localhost --port ${toString cfg.port}";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = "${envs.${cfg.appname}}";
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${cfg.appname}-fastapi-migrate" = {
        path = [ pkgs.bash ];
        description = "migrate ${cfg.appname}-fastapi";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${bins.${cfg.appname}}/bin/${cfg.appname}-manage migrate";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = "${envs.${cfg.appname}}";
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
          Unit = "${cfg.appname}-pgsql-dump.service";
        };
      };
    }) eachSite;

    services.restic.backups.local.paths = flatten (
      mapAttrsToList (name: cfg: [ (stateDir cfg.appname) ]) eachSite
    );

    system.activationScripts = mapAttrs (name: cfg: {
      text = ''
        ${pkgs.systemd}/bin/systemctl start ${cfg.appname}-fastapi-migrate
      '';
    }) eachSite;
  };
}
