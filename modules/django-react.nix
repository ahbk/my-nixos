{ config, lib, ... }:

let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  inherit (builtins) elemAt;
  cfg = config.my-nixos.django-react;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "Django+React app";
      ports = mkOption {
        description = "Listening ports.";
        example = [
          8000
          8001
        ];
        type = listOf port;
      };
      ssl = mkOption {
        description = "Whether to enable SSL (https) support.";
        type = bool;
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
in
{
  options.my-nixos.django-react = with types; {
    sites = mkOption {
      description = "Definition of per-domain Django+React apps to serve.";
      type = attrsOf (submodule siteOpts);
      default = { };
    };
  };

  config = mkIf (eachSite != { }) {

    my-nixos.django.sites = mapAttrs (name: cfg: {
      enable = cfg.enable;
      appname = cfg.appname;
      hostname = cfg.hostname;
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
    }) eachSite;

    my-nixos.react.sites = mapAttrs (name: cfg: {
      enable = cfg.enable;
      ssl = cfg.ssl;
      api = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}/api";
      appname = cfg.appname;
      hostname = cfg.hostname;
    }) eachSite;
  };
}
