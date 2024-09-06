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
    mkEnableOption
    mkOption
    mkIf
    splitString
    types
    ;
  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.react;

  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "react-app for this host.";
      location = mkOption {
        description = "URL path to serve the application.";
        default = "";
        type = str;
      };
      ssl = mkOption {
        description = "Whether the react-app can assume https or not.";
        type = bool;
      };
      api = mkOption {
        description = "URL for the API endpoint";
        type = str;
      };
    };
  };

  reactPkgs = hostname: inputs.${elemAt (splitString "." hostname) 0}.packages.${host.system}.react;

  envs = mapAttrs (
    hostname: cfg:
    (lib'.mkEnv hostname {
      VITE_API_ENDPOINT = cfg.api;
    })
  ) eachSite;
in
{

  options = {
    my-nixos.react = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = { };
        description = "Specification of one or more React sites to serve";
      };
    };
  };

  config = mkIf (eachSite != { }) {
    services.nginx.virtualHosts = mapAttrs (hostname: cfg: {
      serverName = hostname;
      forceSSL = cfg.ssl;
      enableACME = cfg.ssl;
      root = "${ (reactPkgs hostname).app.overrideAttrs { env = envs.${hostname}; } }/dist";
      locations."/${cfg.location}" = {
        index = "index.html";
        extraConfig = ''
          try_files $uri $uri/ /index.html;
        '';
      };
    }) eachSite;
  };
}
