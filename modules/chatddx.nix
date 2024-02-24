{ config, lib, ... }:
with lib;
let
  cfg = config.ahbk.chatddx;
in {
  options.ahbk.chatddx = with types; {
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
    pkgs.django = mkOption {
      type = attrsOf package;
    };
    ports = mkOption {
      type = listOf port;
    };
  };

  config = mkIf cfg.enable {
    ahbk.django.sites.${cfg.hostname} = {
      enable = cfg.enable;
      port = builtins.elemAt cfg.ports 0;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.django;
    };

    ahbk.svelte.sites.${cfg.hostname} = {
      enable = cfg.enable;
      port = builtins.elemAt cfg.ports 1;
      ssl = cfg.ssl;
      pkgs = cfg.pkgs.svelte;
      api = "${if cfg.ssl then "https" else "http"}://${cfg.hostname}";
      api_ssr = "http://localhost:${toString cfg.ports 0}";
    };

  };
}
