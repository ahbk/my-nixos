{
  config,
  host,
  lib,
  ...
}:

let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalString
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

    services.prometheus.exporters.nginx = {
      enable = true;
      scrapeUri = "http://${host.hostname}/nginx_status";
    };
    services.nginx.virtualHosts = {
      "_" = {
        default = true;
        rejectSSL = true;
        locations."/" = {
          return = "444";
        };
      };
      "${host.hostname}" = {
        serverAliases = [ "127.0.0.1" ] ++ optional config.networking.enableIPv6 "[::1]";
        listenAddresses = mkDefault (
          [
            "0.0.0.0"
          ]
          ++ lib.optional config.networking.enableIPv6 "[::]"
        );
        locations."/nginx_status" = {
          extraConfig = ''
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            allow 10.0.0.0/24;
            ${optionalString config.networking.enableIPv6 "allow ::1;"}
            deny all;
          '';
        };
      };
    };
  };
}
