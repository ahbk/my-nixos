{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.svelte;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = {
      enable = mkEnableOption "svelte-app for this host.";
      location = mkOption {
        description = "URL path to serve the application.";
        default = "";
        type = types.str;
      };
      port = mkOption {
        description = "Port to serve the application.";
        type = types.port;
      };
      ssl = mkOption {
        description = "Whether the svelte-app can assume https or not.";
        type = types.bool;
      };
      api = mkOption {
        description = "URL for the API endpoint";
        type = types.str;
      };
      api_ssr = mkOption {
        description = "Server side URL for the API endpoint";
        type = types.str;
      };
      pkgs = mkOption {
        description = "The expected svelte app packages.";
        type = types.attrsOf types.package;
      };
    };
  };

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
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = { };
    }) eachSite;

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: ({
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/${cfg.location}" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    })) eachSite;

    systemd.services = mapAttrs' (
      hostname: cfg:
      (nameValuePair "${hostname}-svelte" {
        description = "serve ${hostname}-svelte";
        serviceConfig = {
          ExecStart = "${pkgs.nodejs_20}/bin/node ${
            cfg.pkgs.app.overrideAttrs ({ env = envs.${hostname}; })
          }/build";
          User = hostname;
          Group = hostname;
          EnvironmentFile = "${envs.${hostname}}";
        };
        wantedBy = [ "multi-user.target" ];
      })
    ) eachSite;
  };
}
