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

  cfg = config.my-nixos.fastapi-svelte;
  eachSite = filterAttrs (hostname: cfg: cfg.enable) cfg.sites;
  siteOpts = {
    options = with types; {
      enable = mkEnableOption "FastAPI+SvelteKit app";
      ssl = mkOption {
        description = "Whether to enable SSL (https) support.";
        type = bool;
      };
      ports = mkOption {
        description = "Listening ports.";
        type = listOf port;
        example = [
          8000
          8001
        ];
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
  options.my-nixos.fastapi-svelte = with types; {
    sites = mkOption {
      description = "Definition of per-domain FastAPI+SvelteKit apps to serve.";
      type = attrsOf (submodule siteOpts);
      default = { };
    };
  };

  config = mkIf (eachSite != { }) {
    my-nixos.fastapi.sites = mapAttrs (name: cfg: {
      enable = cfg.enable;
      appname = cfg.appname;
      hostname = cfg.hostname;
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
    }) eachSite;

    my-nixos.svelte.sites = mapAttrs (name: cfg: {
      enable = cfg.enable;
      appname = cfg.appname;
      hostname = cfg.hostname;
      port = elemAt cfg.ports 1;
      ssl = cfg.ssl;
      api = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}";
      api_ssr = "http://localhost:${toString (elemAt cfg.ports 0)}";
    }) eachSite;
  };
}
