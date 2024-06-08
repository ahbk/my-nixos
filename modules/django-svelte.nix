{ config, lib, ... }:

with lib;
with builtins;

let
  cfg = config.my-nixos.django-svelte;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "Django+SvelteKit app";
      ssl = mkOption {
        description = "Whether to enable SSL (https) support.";
        type = bool;
      };
      ports = mkOption {
        description = "Listening ports.";
        example = [
          8000
          8001
        ];
        type = listOf port;
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
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
    }) eachSite;

    my-nixos.svelte.sites = mapAttrs (hostname: cfg: {
      enable = cfg.enable;
      port = elemAt cfg.ports 1;
      ssl = cfg.ssl;
      api = "${if cfg.ssl then "https" else "http"}://${hostname}";
      api_ssr = "http://localhost:${toString (elemAt cfg.ports 0)}";
    }) eachSite;
  };
}
