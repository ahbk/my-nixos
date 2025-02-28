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
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
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
      appname = mkOption {
        description = "Internal namespace";
        type = str;
      };
      hostname = mkOption {
        description = "Network namespace";
        type = str;
      };
    };
  };

  sveltePkgs = appname: inputs.${appname}.packages.${host.system}.svelte;

  envs = mapAttrs (
    name: cfg:
    (lib'.mkEnv cfg.appname {
      ORIGIN = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}";
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
    users = lib'.mergeAttrs (name: cfg: {
      users.${cfg.appname} = {
        isSystemUser = true;
        group = cfg.appname;
      };
      groups.${cfg.appname} = { };
    }) eachSite;

    services.nginx.virtualHosts = mapAttrs (name: cfg: {
      serverName = cfg.hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."${cfg.location}" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }) eachSite;

    systemd.services = mapAttrs' (
      name: cfg:
      (nameValuePair "${cfg.appname}-svelte" {
        description = "serve ${cfg.appname}-svelte";
        serviceConfig = {
          ExecStart = "${pkgs.nodejs_20}/bin/node ${
            (sveltePkgs cfg.appname).overrideAttrs { env = envs.${cfg.appname}; }
          }/build";
          User = cfg.appname;
          Group = cfg.appname;
          EnvironmentFile = "${envs.${cfg.appname}}";
        };
        wantedBy = [ "multi-user.target" ];
      })
    ) eachSite;
  };
}
