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
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optionalAttrs
    splitString
    types
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
      user = mkOption {
        description = "Username for app owner";
        type = str;
      };
      locationStatic = mkOption {
        description = "Location pattern for static files, empty string -> no static";
        type = str;
        default = "/static/";
      };
      locationProxy = mkOption {
        description = "Location pattern for proxy to django, empty string -> no proxy";
        type = str;
        example = "~ ^/(api|admin)";
        default = "/";
      };
    };
  };

  djangoPkgs = hostname: inputs.${elemAt (splitString "." hostname) 0}.packages.${host.system}.django;

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
      locations =
        optionalAttrs (cfg.locationProxy != "") {
          ${cfg.locationProxy} = {
            recommendedProxySettings = true;
            proxyPass = "http://localhost:${toString cfg.port}";
          };
        }
        // optionalAttrs (cfg.locationStatic != "") {
          ${cfg.locationStatic} = {
            alias = "${(djangoPkgs hostname).static}/";
          };
        };
    }) eachSite;

    systemd.services = lib'.mergeAttrs (hostname: cfg: {
      "${hostname}-django" = {
        description = "serve ${hostname}-django";
        serviceConfig = {
          ExecStart = "${(djangoPkgs hostname).app.dependencyEnv}/bin/gunicorn app.wsgi:application --bind localhost:${toString cfg.port}";
          User = cfg.user;
          Group = cfg.user;
          EnvironmentFile = "${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      };

      "${hostname}-django-migrate" = {
        description = "migrate ${hostname}-django";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${(djangoPkgs hostname).app.dependencyEnv}/bin/django-admin migrate";
          User = cfg.user;
          Group = cfg.user;
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
