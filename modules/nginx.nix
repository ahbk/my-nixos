{ config, lib, ... }:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.nginx;
in
{
  options.my-nixos.nginx = with types; {
    enable = mkEnableOption "nginx web server.";
    email = mkOption {
      description = "Email for ACME certificate updates";
      type = str;
    };
  };
  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.email;
    };

    services.nginx = {
      enable = true;
      recommendedBrotliSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      commonHttpConfig = ''
        log_format main '$time_iso8601 [$status] $remote_addr - '
                        '$scheme://$host "$request" $http_referer '
                        '"$http_user_agent" $body_bytes_sent';

        access_log /var/log/nginx/access.log main;
      '';

      appendConfig = ''
        worker_processes auto;
        worker_cpu_affinity auto;
      '';
    };

    services.nginx.virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/" = {
        return = "444";
      };
    };
  };
}
