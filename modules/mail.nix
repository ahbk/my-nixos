{ config, lib, ... }:
with lib;
let
  cfg = config.ahbk.mail;
in {

  options = {
    ahbk.mail = {
      enable = mkOption {
        default = false;
        type = types.bool;
      };
      hostname = mkOption {
        type = types.str;
      };
      ssl = mkOption {
        type = types.bool;
      };
    };
  };

  config = mkIf (cfg.enable) {

    services.postfix = {
      enable = true;
      sslCert = config.security.acme.certs.${cfg.hostname}.directory + "/full.pem";
      sslKey = config.security.acme.certs.${cfg.hostname}.directory + "/key.pem";
    };

    services.nginx.virtualHosts.${cfg.hostname} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        return = "444";
      };
    };

    networking.firewall.allowedTCPPorts = [ 25 80 443 ];
  };
}

