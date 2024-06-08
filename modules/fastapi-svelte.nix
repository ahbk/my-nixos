{ config, lib, ... }:

with lib;
with builtins;

let
  cfg = config.my-nixos.fastapi-svelte;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  siteOpts = {
    options = with types; {
      enable = mkEnableOption "fastapi-svelte";
      ssl = mkOption {
        description = "HTTPS";
        type = bool;
      };
      pkgs.svelte = mkOption {
        description = "svelte packages";
        type = attrsOf package;
      };
      pkgs.fastapi = mkOption {
        description = "fastapi packages";
        type = attrsOf package;
      };
      ports = mkOption {
        description = "two ports";
        type = listOf port;
        example = [
          8000
          8001
        ];
      };
    };
  };

in
{
  options.my-nixos.fastapi-svelte = with types; {
    sites = mkOption {
      description = "Specification of one or more FastAPI+SvelteKit sites to serve";
      type = attrsOf (submodule siteOpts);
      default = { };
    };
  };

  config = mkIf (eachSite != { }) {
    my-nixos.fastapi.sites = mapAttrs (hostname: cfg: {
      enable = cfg.enable;
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.fastapi;
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
