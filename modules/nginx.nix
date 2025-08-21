{
  config,
  host,
  ids,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
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
        log_format main escape=json '{'
          '"time_iso8601": "$time_iso8601", '
          '"status": "$status", '
          '"remote_addr": "$remote_addr", '
          '"remote_user": "$remote_user", '
          '"request_method": "$request_method", '
          '"request_uri": "$request_uri", '
          '"server_protocol": "$server_protocol", '
          '"host": "$host", '
          '"scheme": "$scheme", '
          '"request_length": "$request_length", '
          '"body_bytes_sent": $body_bytes_sent, '
          '"http_referer": "$http_referer", '
          '"http_user_agent": "$http_user_agent", '
          '"http_x_forwarded_for": "$http_x_forwarded_for", '
          '"request_time": "$request_time", '
          '"upstream_addr": "$upstream_addr", '
          '"upstream_status": "$upstream_status", '
          '"upstream_response_time": "$upstream_response_time", '
          '"upstream_connect_time": "$upstream_connect_time" '
        '}';

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
      "${host.hostname}".locations."/nginx_status" = {
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

    #services.alloy = {
    #  enable = true;
    #  extraFlags = [
    #    "--server.http.listen-addr=0.0.0.0:${toString ids.alloy.port}"
    #  ];
    #};
    #users.users.alloy = {
    #  uid = ids.alloy.uid;
    #  isSystemUser = true;
    #  group = "alloy";
    #  extraGroups = [ "nginx" ];
    #};
    #users.groups.alloy = {
    #  gid = config.users.users.alloy.uid;
    #};

    environment.etc."alloy/config.alloy".text = ''
      local.file_match "nginx_json_access_log" {
          path_targets = [
              {
              "__path__" = "/var/log/nginx/access.log",
              "job" = "nginx",
              "log_instance" = "${host.hostname}",
              "log_type" = "access_json",
              },
          ]
      }

      local.file_match "nginx_plain_error_log" {
          path_targets = [
              {
              "__path__" = "/var/log/nginx/error.log",
              "job" = "nginx",
              "log_instance" = "${host.hostname}",
              "log_type" = "error_plain",
              },
          ]
      }

      loki.source.file "nginx_access_source" {
          targets    = local.file_match.nginx_json_access_log.targets
          forward_to = [loki.process.nginx_json_parser.receiver]
      }

      loki.source.file "nginx_error_source" {
          targets    = local.file_match.nginx_plain_error_log.targets
          forward_to = [loki.write.default.receiver]
      }

      loki.process "nginx_json_parser" {
          stage.json {
              expressions = {
                  "host" = "",
                  "status" = "",
              }
          }

          stage.labels {
              values = {
                  host   = "",
                  status = "",
              }
          }

          stage.timestamp {
              source = "time_iso8601"
              format = "RFC3339"
          }

          forward_to = [loki.write.default.receiver]
      }

      loki.write "default" {
          endpoint {
              url = "http://stationary.ahbk:3100/loki/api/v1/push"
          }
      }
    '';
  };
}
