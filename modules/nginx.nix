{ config, lib, ... }:

let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
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
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

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
