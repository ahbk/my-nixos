{
  config,
  host,
  inputs,
  lib,
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

  cfg = config.my-nixos.react;

  eachSite = filterAttrs (name: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "react-app for this host.";
      location = mkOption {
        description = "URL path to serve the application.";
        default = "/";
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

  reactPkgs' = appname: inputs.${appname}.packages.${host.system}.vite-static;

  reactPkgs = mapAttrs (
    name: cfg:
    (reactPkgs' cfg.appname).overrideAttrs {
      env = {
        VITE_API_ENDPOINT = cfg.api;
      };
    }
  ) cfg.sites;
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
    services.nginx.virtualHosts = mapAttrs' (
      name: cfg:
      nameValuePair cfg.hostname {
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        root = "${reactPkgs.${cfg.appname}}/dist";
        locations."${cfg.location}" = {
          index = "index.html";
          extraConfig = ''
            try_files $uri $uri/ /index.html;
          '';
        };
      }
    ) eachSite;
  };
}
