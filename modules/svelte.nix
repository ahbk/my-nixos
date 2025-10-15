{
  config,
  host,
  inputs,
  lib,
  lib',
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  cfg = config.my-nixos.svelte;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts =
    { name, config, ... }:
    {
      options = with types; {
        enable = mkEnableOption "svelte-app for this host.";
        location = mkOption {
          description = "URL path to serve the application.";
          default = "/";
          type = str;
        };
        port = mkOption {
          description = "Port to serve the application.";
          default = lib'.ids."${config.appname}-svelte".port;
          type = port;
        };
        ssl = mkOption {
          description = "Whether the svelte-app can assume https or not.";
          default = true;
          type = bool;
        };
        api = mkOption {
          description = "URL for the API endpoint";
          type = str;
        };
        api_ssr = mkOption {
          description = "Server side URL for the API endpoint";
          type = str;
        };
        appname = mkOption {
          description = "Internal namespace";
          default = name;
          type = str;
        };
        hostname = mkOption {
          description = "Network namespace";
          type = str;
        };
      };
    };

  sveltePkgs =
    appname:
    inputs.${appname}.packages.${host.system}.svelte-app.overrideAttrs {
      env = envs.${appname};
    };

  envs = mapAttrs (name: cfg: {
    ORIGIN = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}";
    PUBLIC_API = cfg.api;
    PUBLIC_API_SSR = cfg.api_ssr;
    PORT = toString cfg.port;
  }) eachSite;
in
{

  options = {
    my-nixos.svelte = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = { };
        description = "Specification of one or more Svelte sites to serve";
      };
    };
  };

  config = mkIf (eachSite != { }) {
    my-nixos.users = lib.mapAttrs' (
      name: cfg:
      lib.nameValuePair "${cfg.appname}-svelte" {
        class = "service";
        publicKey = false;
      }
    ) eachSite;

    services.nginx.virtualHosts = mapAttrs' (
      name: cfg:
      nameValuePair cfg.hostname {
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        locations."${cfg.location}" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
        };
      }
    ) eachSite;

    systemd.services = mapAttrs' (
      name: cfg:
      (nameValuePair "${cfg.appname}-svelte" {
        description = "serve ${cfg.appname}-svelte";
        serviceConfig = {
          ExecStart = "${pkgs.nodejs_20}/bin/node ${sveltePkgs cfg.appname}/build";
          Environment = lib'.envToList envs.${cfg.appname};
          User = "${cfg.appname}-svelte";
          Group = "${cfg.appname}-svelte";
        };
        wantedBy = [ "multi-user.target" ];
      })
    ) eachSite;
  };
}
