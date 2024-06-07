{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my-nixos.nginx;
in {
  options.my-nixos.nginx = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    email = mkOption {
      type = types.str;
    };
  };
  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.email;
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    services.nginx.virtualHosts."_" = {
      default = true;
      locations."/" = {
        return = "444";
      };
    };
  };
}
