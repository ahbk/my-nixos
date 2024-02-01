{ config, lib, pkgs, ... }:
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
      api = {
        type = types.submodule {
          options = {
            port = mkOption {
              type = types.port;
            };
            location = mkOption {
              type = types.str;
            };
          };
        };
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

  envs = mapAttrs (hostname: cfg: (pkgs.writeText "${hostname}-env" (concatStringsSep "\n" (mapAttrsToList (k: v: "${k}=${v}") {
    PUBLIC_SCHEME = if cfg.ssl then "https" else "http";
    PUBLIC_HOST = hostname;
    PUBLIC_API_PORT = cfg.api.port;
    PUBLIC_API_LOCATION = cfg.api.location;
  })))) eachSite;
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
    users = foldlAttrs (acc: hostname: cfg: (recursiveUpdate acc {
      users.${hostname} = {
        isSystemUser = true;
        group = hostname;
      };
      groups.${hostname} = {};
    })) {} eachSite;

    services.nginx.virtualHosts = mapAttrs (hostname: cfg: ({
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      locations."/${cfg.location}" = {
        recommendedProxySettings = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    })) eachSite;

    systemd.services = mapAttrs (hostname: cfg: (
      nameValuePair "${hostname}-svelte" {
      description = "manage ${hostname}-svelte";
      serviceConfig = {
        ExecStart = "${pkgs.nodejs_20}/bin/node ${cfg.app.override({ env = envs.${hostname}; })}/build";
        User = hostname;
        Group = hostname;
        EnvironmentFile="${envs.${hostname}}";
      };
      wantedBy = [ "multi-user.target" ];
    })) eachSite;

  };
}
