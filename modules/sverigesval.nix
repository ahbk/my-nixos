{ config, lib, ... }:
with lib;
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
    host = mkOption {
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

  config = mkIf cfg.enable rec {
    ahbk.fastapi.sites.${cfg.host} = {
      enable = cfg.enable;
      port = builtins.elemAt cfg.ports 0;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.fastapi;
    };

    ahbk.svelte.sites.${cfg.host} = {
      enable = cfg.enable;
      port = builtins.elemAt cfg.ports 1;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.svelte;
      api = {
        port = ahbk.fastapi.sites.${cfg.host}.port;
      };
    };

  };
}
