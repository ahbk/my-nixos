{ config, lib, ... }:

let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    mapAttrs
    filterAttrs
    mkDefault
    mkIf
    ;
  inherit (builtins) elemAt;
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
      user = mkOption {
        description = "Username for app owner";
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

    my-nixos.django.sites = mapAttrs (hostname: cfg: {
      enable = cfg.enable;
      user = cfg.user;
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
      staticLocation = mkDefault "static/";
    }) eachSite;

    my-nixos.svelte.sites = mapAttrs (hostname: cfg: {
      enable = cfg.enable;
      user = cfg.user;
      port = elemAt cfg.ports 1;
      ssl = cfg.ssl;
      api = "${if cfg.ssl then "https" else "http"}://${hostname}";
      api_ssr = "http://localhost:${toString (elemAt cfg.ports 0)}";
    }) eachSite;
  };
}
