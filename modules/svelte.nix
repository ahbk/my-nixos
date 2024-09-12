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
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    splitString
    types
    ;

  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.svelte;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "svelte-app for this host.";
      location = mkOption {
        description = "URL path to serve the application.";
        default = "/";
        type = str;
      };
      port = mkOption {
        description = "Port to serve the application.";
        type = port;
      };
      ssl = mkOption {
        description = "Whether the svelte-app can assume https or not.";
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
      user = mkOption {
        description = "Username for app owner";
        type = str;
      };
    };
  };

  sveltePkgs = hostname: inputs.${elemAt (splitString "." hostname) 0}.packages.${host.system}.svelte;

  envs = mapAttrs (
    hostname: cfg:
    (lib'.mkEnv hostname {
      ORIGIN = "${if cfg.ssl then "https" else "http"}://${hostname}";
      PUBLIC_API = cfg.api;
      PUBLIC_API_SSR = cfg.api_ssr;
      PORT = toString cfg.port;
    })
  ) eachSite;
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
    users = lib'.mergeAttrs (hostname: cfg: {
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
      };
      groups.${cfg.user} = { };
    }) eachSite;

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: {
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."${cfg.location}" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }) eachSite;

    systemd.services = mapAttrs' (
      hostname: cfg:
      (nameValuePair "${hostname}-svelte" {
        description = "serve ${hostname}-svelte";
        serviceConfig = {
          ExecStart = "${pkgs.nodejs_20}/bin/node ${
            (sveltePkgs hostname).app.overrideAttrs { env = envs.${hostname}; }
          }/build";
          User = cfg.user;
          Group = cfg.user;
          EnvironmentFile = "${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      })
    ) eachSite;
  };
}
