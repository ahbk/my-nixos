{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.ahbk.django;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/django";

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
    DJANGO_SETTINGS_MODULE = "app.settings";
  })))) eachSite;

  bins = mapAttrsToList (hostname: cfg: (cfg.pkgs.bin.overrideAttrs {
    env = envs.${hostname};
    name = "${hostname}-manage";
  })) eachSite;

in {
  options = {
    ahbk.django = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = {};
        description = mdDoc "Specification of one or more Django sites to serve";
      };
    };
  };

  config = mkIf (eachSite != {}) {

    environment.systemPackages = bins;

    age.secrets = mapAttrs (hostname: cfg: ({
      file = ./secrets/${hostname}.age;
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
      locations."/${cfg.location}static/" = {
        alias = "${cfg.pkgs.static}/";
      };
    })) eachSite;

    systemd.services = mapAttrs (hostname: cfg: (
      nameValuePair "${hostname}-django" {
      description = "manage ${hostname}-django";
      serviceConfig = {
        ExecStart = "${cfg.pkgs.app.dependencyEnv}/bin/gunicorn app.wsgi:application --bind localhost:${toString cfg.port}";
        User = hostname;
        Group = hostname;
        EnvironmentFile="${envs.${hostname}}";
      };
      wantedBy = [ "multi-user.target" ];
    })) eachSite;

  };
}
