{ config, lib, ... }:

let
  inherit (lib)
    elemAt
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.django-svelte;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "Django+SvelteKit app";
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
  options.my-nixos.django-svelte = with types; {
    sites = mkOption {
      description = "Definition of per-domain Django+SvelteKit apps to serve.";
      type = attrsOf (submodule siteOpts);
      default = { };
    };
  };

  config = mkIf (eachSite != { }) {

    my-nixos = {
      django.sites = mapAttrs (name: cfg: {
        enable = cfg.enable;
        appname = cfg.appname;
        hostname = cfg.hostname;
        port = elemAt cfg.ports 0;
        ssl = cfg.ssl;
      }) eachSite;

      svelte.sites = mapAttrs (name: cfg: {
        enable = cfg.enable;
        appname = cfg.appname;
        hostname = cfg.hostname;
        port = elemAt cfg.ports 1;
        ssl = cfg.ssl;
        api = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}";
        api_ssr = "http://localhost:${toString (elemAt cfg.ports 0)}";
      }) eachSite;
    };
  };
}
