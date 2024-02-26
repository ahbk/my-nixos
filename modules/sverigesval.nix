{ config, lib, ... }:
with lib;
with builtins;
let
  cfg = config.ahbk.sverigesval;
in {
  options.ahbk.sverigesval = with types; {
    enable = mkOption {
      type = bool;
      default = false;
    };
    ssl = mkOption {
      type = bool;
    };
    hostname = mkOption {
      type = str;
    };
    pkgs.svelte = mkOption {
      type = attrsOf package;
    };
    pkgs.fastapi = mkOption {
      type = attrsOf package;
    };
    ports = mkOption {
      type = listOf port;
    };
  };

  config = mkIf cfg.enable {
    ahbk.fastapi.sites.${cfg.hostname} = {
      enable = cfg.enable;
      port = elemAt cfg.ports 0;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.fastapi;
    };

    ahbk.svelte.sites.${cfg.hostname} = {
      enable = cfg.enable;
      port = elemAt cfg.ports 1;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.svelte;
      api = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}";
      api_ssr = "http://localhost:${toString (elemAt cfg.ports 0)}";
    };

  };
}
