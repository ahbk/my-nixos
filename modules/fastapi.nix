{ config, lib, pkgs, ... }:
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
      location = mkOption {
        default = "";
        type = types.str;
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

  envs = mapAttrs (hostname: cfg: (pkgs.writeText "${hostname}-env" (concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${v}") {
    DEBUG = "false";
    SECRET_KEY_FILE = config.age.secrets.${hostname}.path;
    SCHEME = if cfg.ssl then "https" else "http";
    APP_ROOT = cfg.location;
    STATE_DIR = stateDir hostname;
    HOST = hostname;
  })))) eachSite;

  bins = mapAttrsToList (hostname: cfg: (cfg.pkgs.bin.override {
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
    imports = [
      ./postgresql.nix
    ];

    environment.systemPackages = bins;

    age.secrets = mapAttrs' (hostname: cfg: (
      nameValuePair "$hostname_key" {
      file = ./secrets/${hostname}_key.age;
      owner = hostname;
      group = hostname;
    })) eachSite;

    users = foldlAttrs (acc: hostname: cfg: (recursiveUpdate acc {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = {};
    })) {} eachSite;

    ahbk.postgresql = mapAttrs (hostname: cfg: { ensure = true; });

    systemd.tmpfiles.rules = flatten (mapAttrsToList (hostname: cfg: [
      "d '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
      "Z '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
    ]) eachSite);

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: ({
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/${cfg.location}" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    })) eachSite;

    systemd.services = foldlAttrs (acc: hostname: cfg: (recursiveUpdate acc {
      "${hostname}-fastapi" = {
        description = "manage ${hostname}-fastap";
        serviceConfig = {
          ExecStart = "${cfg.pkgs.app.dependencyEnv}/bin/uvicorn app.main:run --bind localhost:${toString cfg.port}";
          User = hostname;
          Group = hostname;
          EnvironmentFile="${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      };
      "${hostname}-setup" = {
        description = "${hostname-setup}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${cfg.pkgs.bin}/bin/manage setup";
          User = cfg.user;
          Group = cfg.user;
          EnvironmentFile="${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
        before = [ "rolf-api.service" ];
      };
    })) eachSite;
  };
}
