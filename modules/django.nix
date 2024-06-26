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
    types
    mkEnableOption
    mkOption
    mkIf
    filterAttrs
    mapAttrsToList
    mapAttrs
    mapAttrs'
    flatten
    nameValuePair
    ;
  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.django;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  stateDir = hostname: "/var/lib/${hostname}/django";

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "Django app";
      port = mkOption {
        description = "Listening port.";
        example = 8000;
        type = port;
      };
      ssl = mkOption {
        description = "Whether to enable SSL (https) support.";
        type = bool;
      };
    };
  };

  djangoPkgs = hostname: inputs.${hostname}.packages.${host.system}.django;

  envs = mapAttrs (
    hostname: cfg:
    (lib'.mkEnv hostname {
      DEBUG = "false";
      SECRET_KEY_FILE = config.age.secrets."${hostname}/secret-key".path;
      SCHEME = if cfg.ssl then "https" else "http";
      STATE_DIR = stateDir hostname;
      HOST = hostname;
      DJANGO_SETTINGS_MODULE = "app.settings";
    })
  ) eachSite;

  bins = mapAttrs (
    hostname: cfg:
    ((djangoPkgs hostname).bin.overrideAttrs {
      env = envs.${hostname};
      name = "${hostname}-manage";
    })
  ) eachSite;
in
{

  options.my-nixos.django = with types; {
    sites = mkOption {
      type = attrsOf (submodule siteOpts);
      default = { };
      description = "Definition of per-domain Django apps to serve.";
    };
  };

  config = mkIf (eachSite != { }) {

    environment.systemPackages = mapAttrsToList (hostname: bin: bin) bins;

    age.secrets = mapAttrs' (
      hostname: cfg:
      (nameValuePair "${hostname}/secret-key" {
        file = ../secrets/webapp-key-${hostname}.age;
        owner = hostname;
        group = hostname;
      })
    ) eachSite;

    users = lib'.mergeAttrs (hostname: cfg: {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = { };
    }) eachSite;

    systemd.tmpfiles.rules = flatten (
      mapAttrsToList (hostname: cfg: [
        "d '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
        "Z '${stateDir hostname}' 0750 ${hostname} ${hostname} - -"
      ]) eachSite
    );

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: ({
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/admin" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
      locations."/static/" = {
        alias = "${(djangoPkgs hostname).static}/";
      };
    })) eachSite;

    systemd.services = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-django" = {
        description = "serve ${hostname}-django";
        serviceConfig = {
          ExecStart = "${(djangoPkgs hostname).app.dependencyEnv}/bin/gunicorn app.wsgi:application --bind localhost:${toString cfg.port}";
          User = hostname;
          Group = hostname;
          EnvironmentFile = "${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${hostname}-django-migrate" = {
        description = "migrate ${hostname}-django";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${(djangoPkgs hostname).app.dependencyEnv}/bin/django-admin migrate";
          User = hostname;
          Group = hostname;
          EnvironmentFile = "${envs.${hostname}}";
        };
      };
    }) eachSite;

    my-nixos.backup."backup.ahbk".paths = flatten (
      mapAttrsToList (hostname: cfg: [ (stateDir hostname) ]) eachSite
    );

    system.activationScripts = mapAttrs (hostname: cfg: {
      text = ''
        ${pkgs.systemd}/bin/systemctl start ${hostname}-django-migrate
      '';
    }) eachSite;
  };
}
