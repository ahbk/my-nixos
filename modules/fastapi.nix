{ config
, lib
, lib'
, pkgs
, ...
}:

with lib;

let
  cfg = config.ahbk.fastapi;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/fastapi";

  siteOpts = { lib, name, config, ... }: {
    options = {
      enable = mkOption {
        default = true;
        type = types.bool;
      };
      port = mkOption {
        type = types.port;
      };
      ssl = mkOption {
        type = types.bool;
      };
      pkgs = mkOption {
        type = types.attrsOf types.package;
      };
    };
  };

  envs = mapAttrs (hostname: cfg: (lib'.mkEnv hostname {
    HOSTNAME = hostname;
    ENV = "production";
    SSL = if cfg.ssl then "true" else "false";
    STATE_DIR = stateDir hostname;
    SECRETS_DIR = builtins.dirOf config.age.secrets."${hostname}/secret_key".path;
    ALLOW_ORIGINS = "'[\"${if cfg.ssl then "https" else "http"}://${hostname}\"]'";
  })) eachSite;

  bins = mapAttrs (hostname: cfg: (cfg.pkgs.bin.overrideAttrs {
    env = envs.${hostname};
    name = "${hostname}-manage";
  })) eachSite;

in {

  options = {
    ahbk.fastapi = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = {};
        description = mdDoc "Specification of one or more FastAPI sites to serve";
      };
    };
  };

  config = mkIf (eachSite != {}) {

    environment.systemPackages = mapAttrsToList (hostname: bin: bin) bins;

    age.secrets = mapAttrs' (hostname: cfg: (
      nameValuePair "${hostname}/secret_key" {
      file = ../secrets/${hostname}-secret-key.age;
      owner = hostname;
      group = hostname;
    })) eachSite;

    users = lib'.mergeAttrs (hostname: cfg: {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = {};
    }) eachSite;

    ahbk.postgresql = mapAttrs (hostname: cfg: { ensure = true; }) eachSite;

    systemd.tmpfiles.rules = flatten (mapAttrsToList (hostname: cfg: [
      "d '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
      "Z '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
    ]) eachSite);

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: ({
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/api" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    })) eachSite;

    systemd.services = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-fastapi" = {
        description = "serve ${hostname}-fastapi";
        serviceConfig = {
          ExecStart = "${cfg.pkgs.app.dependencyEnv}/bin/uvicorn app.main:run --host localhost --port ${toString cfg.port}";
          User = hostname;
          Group = hostname;
          EnvironmentFile="${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${hostname}-fastapi-migrate" = {
        path = [pkgs.bash];
        description = "migrate ${hostname}-fastapi";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${cfg.pkgs.bin}/bin/manage migrate";
          User = hostname;
          Group = hostname;
          EnvironmentFile="${envs.${hostname}}";
        };
      };
    }) eachSite;

    system.activationScripts = mapAttrs (hostname: cfg: {
      text = ''
        ${pkgs.systemd}/bin/systemctl start ${hostname}-fastapi-migrate
      '';
    }) eachSite;
  };
}
