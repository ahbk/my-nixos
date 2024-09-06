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
    elemAt
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
    splitString
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
      user = mkOption {
        description = "Username for app owner";
        type = str;
        default = null;
      };
    };
  };

  fastapiPkgs = hostname: inputs.${elemAt (splitString "." hostname) 0}.packages.${host.system}.fastapi;

  envs = mapAttrs (
    hostname: cfg:
    (lib'.mkEnv hostname {
      ALLOW_ORIGINS = "'[\"${if cfg.ssl then "https" else "http"}://${hostname}\"]'";
      DB_DSN = "postgresql+psycopg2://${hostname}@:5432/${hostname}";
      ENV = "production";
      HOSTNAME = hostname;
      LOG_LEVEL = "error";
      SECRETS_DIR = builtins.dirOf config.age.secrets."${hostname}/secret_key".path;
      SSL = if cfg.ssl then "true" else "false";
      STATE_DIR = stateDir hostname;
    })
  ) eachSite;

  bins = mapAttrs (
    hostname: cfg:
    ((fastapiPkgs hostname).bin.overrideAttrs {
      env = envs.${hostname};
      name = "${hostname}-manage";
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

    environment.systemPackages = mapAttrsToList (hostname: bin: bin) bins;

    age.secrets = mapAttrs' (
      hostname: cfg:
      (nameValuePair "${hostname}/secret_key" {
        file = ../secrets/webapp-key-${hostname}.age;
        owner = cfg.user;
        group = cfg.user;
      })
    ) eachSite;

    users = lib'.mergeAttrs (hostname: cfg: {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
      };
      groups.${cfg.user} = { };
    }) eachSite;

    my-nixos.postgresql = mapAttrs (hostname: cfg: { ensure = true; }) eachSite;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (hostname: cfg: [
        "d '${stateDir hostname}' 0750 ${cfg.user} ${cfg.user} - -"
        "Z '${stateDir hostname}' 0750 ${cfg.user} ${cfg.user} - -"
      ]) eachSite
    );

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: {
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/api" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }) eachSite;

    systemd.services = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-fastapi" = {
        description = "serve ${hostname}-fastapi";
        serviceConfig = {
          ExecStart = "${(fastapiPkgs hostname).app.dependencyEnv}/bin/uvicorn app.main:fastapi --host localhost --port ${toString cfg.port}";
          User = cfg.user;
          Group = cfg.user;
          EnvironmentFile = "${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${hostname}-fastapi-migrate" = {
        path = [ pkgs.bash ];
        description = "migrate ${hostname}-fastapi";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${(fastapiPkgs hostname).bin}/bin/manage migrate";
          User = cfg.user;
          Group = cfg.user;
          EnvironmentFile = "${envs.${hostname}}";
        };
      };

      "${hostname}-pgsql-dump" = {
        description = "dump a snapshot of the postgresql database";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.postgresql}/bin/pg_dump -U ${hostname} ${hostname} > ${stateDir hostname}/dbdump.sql'";
          User = cfg.user;
          Group = cfg.user;
        };
      };
      "${hostname}-pgsql-restore" = {
        description = "restore postgresql database from snapshot";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.bash} -c '${pkgs.postgresql}/bin/psql -U ${hostname} ${hostname} < ${stateDir hostname}/dbdump.sql'";
          User = cfg.user;
          Group = cfg.user;
        };
      };
    }) eachSite;

    systemd.timers = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-pgsql-dump" = {
        description = "Scheduled PostgreSQL database dump";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Unit = "${hostname}-pgsql-dump";
        };
      };
    }) eachSite;

    my-nixos.backup."backup.ahbk".paths = flatten (
      mapAttrsToList (hostname: cfg: [ (stateDir hostname) ]) eachSite
    );

    system.activationScripts = mapAttrs (hostname: cfg: {
      text = ''
        ${pkgs.systemd}/bin/systemctl start ${hostname}-fastapi-migrate
      '';
    }) eachSite;
  };
}
