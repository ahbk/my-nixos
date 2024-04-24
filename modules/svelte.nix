{ config
, lib
, lib'
, pkgs
, ...
}:

with lib;

let
  cfg = config.ahbk.svelte;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
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
      api = mkOption {
        type = types.str;
      };
      api_ssr = mkOption {
        type = types.str;
      };
      pkgs = mkOption {
        type = types.submodule {
          options = {
            app = mkOption {
              type = types.package;
            };
          };
        };
      };
    };
  };

  envs = mapAttrs (hostname: cfg: (lib'.mkEnv hostname {
    ORIGIN = "${if cfg.ssl then "https" else "http"}://${hostname}";
    PUBLIC_API = cfg.api;
    PUBLIC_API_SSR = cfg.api_ssr;
    PORT = toString cfg.port;
  })) eachSite;
in {

  options = {
    ahbk.svelte = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = {};
        description = mdDoc "Specification of one or more Svelte sites to serve";
      };
    };
  };

  config = mkIf (eachSite != {}) {
    users = lib'.mergeAttrs (hostname: cfg: {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = {};
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

    systemd.services = mapAttrs' (hostname: cfg: (
      nameValuePair "${hostname}-svelte" {
      description = "serve ${hostname}-svelte";
      serviceConfig = {
        ExecStart = "${pkgs.nodejs_20}/bin/node ${cfg.pkgs.app.overrideAttrs({ env = envs.${hostname}; })}/build";
        User = hostname;
        Group = hostname;
        EnvironmentFile="${envs.${hostname}}";
      };
      wantedBy = [ "multi-user.target" ];
    })) eachSite;

  };
}
