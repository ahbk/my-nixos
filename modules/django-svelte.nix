{ config, lib, ... }:

with lib;
with builtins;

let
  cfg = config.my-nixos.django-svelte;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;

  siteOpts = {
    options = with types; {
      enable = mkEnableOption "Django+SvelteKit site for this host.";
      ssl = mkOption {
        description = "HTTPS";
        type = bool;
      };
      pkgs.svelte = mkOption {
        description = "Svelte packages";
        type = attrsOf package;
      };
      pkgs.django = mkOption {
        description = "Django packages";
        type = attrsOf package;
      };
      ports = mkOption {
        description = "Two ports";
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
      type = attrsOf (submodule siteOpts);
      default = { };
      description = "Specification of one or more Django+SvelteKit sites to serve";
    };
  };

  config = mkIf (eachSite != { }) {

    my-nixos.django.sites = mapAttrs (hostname: cfg: {
      enable = cfg.enable;
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.django;
    }) eachSite;

    my-nixos.svelte.sites = mapAttrs (hostname: cfg: {
      enable = cfg.enable;
      port = elemAt cfg.ports 1;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.svelte;
      api = "${if cfg.ssl then "https" else "http"}://${hostname}";
      api_ssr = "http://localhost:${toString (elemAt cfg.ports 0)}";
    }) eachSite;
  };
}
