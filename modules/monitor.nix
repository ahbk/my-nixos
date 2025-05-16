{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.my-nixos.monitor;
  blackboxConfig = {
    modules = {
      http_2xx = {
        prober = "http";
        timeout = "5s";
        http = {
          valid_http_versions = [
            "HTTP/1.1"
            "HTTP/2"
            "HTTP/2.0"
          ];
          valid_status_codes = [ ];
          follow_redirects = true;
          preferred_ip_protocol = "ip4";
          tls_config = {
            insecure_skip_verify = false;
          };
        };
      };
      http_post_2xx = {
        prober = "http";
        timeout = "5s";
        http = {
          method = "POST";
          valid_http_versions = [
            "HTTP/1.1"
            "HTTP/2"
          ];
          valid_status_codes = [ ];
          follow_redirects = true;
          preferred_ip_protocol = "ip4";
        };
      };
      tcp_connect = {
        prober = "tcp";
        timeout = "5s";
      };
      icmp = {
        prober = "icmp";
        timeout = "5s";
        icmp = {
          preferred_ip_protocol = "ip4";
        };
      };
    };
  };
in
{
  options.my-nixos.monitor = {
    enable = mkEnableOption "gathering metrics";
  };
  config = mkIf (cfg.enable) {
    services.prometheus = {
      enable = true;
      exporters.blackbox = {
        enable = true;
        configFile = pkgs.writeText "blackbox.json" (builtins.toJSON blackboxConfig);
        extraFlags = [
          "--log.level=warn"
        ];
      };
      scrapeConfigs = with config.services.prometheus.exporters; [
        {
          job_name = "mail";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString postfix.port}"
                "glesys.ahbk:${toString dovecot.port}"
                "glesys.ahbk:${toString rspamd.port}"
              ];
              labels = {
                service = "mail";
              };
            }
          ];
        }
        {
          job_name = "backup";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString restic.port}"
                "stationary.ahbk:${toString restic.port}"
                "backup.ahbk:${toString config.my-nixos.backup.local.port}"
                "laptop.ahbk:${toString restic.port}"
              ];
              labels = {
                service = "backup";
              };
            }
          ];
        }
        {
          job_name = "php-fpm";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString php-fpm.port}"
                "stationary.ahbk:${toString php-fpm.port}"
              ];
              labels = {
                service = "php-fpm";
              };
            }
          ];
        }
        {
          job_name = "redis";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString redis.port}"
                "stationary.ahbk:${toString redis.port}"
              ];
              labels = {
                service = "redis";
              };
            }
          ];
        }
        {
          job_name = "postgres";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString postgres.port}"
                "stationary.ahbk:${toString postgres.port}"
              ];
              labels = {
                service = "postgres";
              };
            }
          ];
        }
        {
          job_name = "probe_websites";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
            target = [ "__param_target__" ]; # This tells blackbox which target to probe
          };
          static_configs = [
            {
              targets = [
                "https://kompismoln.se"
                "https://esse.nu"
                "https://chatddx.com"
                "https://sverigesval.org"
                "https://sysctl-user-portal.curetheweb.se"
              ];
              labels = {
                service = "website";
              };
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target"; # Use the original target as a URL parameter
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance"; # Keep the original URL as the instance label
            }
            {
              source_labels = [ "__param_target" ];
              regex = "https?://([^/:]+).*"; # Extract domain name
              target_label = "domain"; # Save domain as a separate label
            }
            {
              target_label = "__address__";
              replacement = "stationary.ahbk:9115"; # Point to the blackbox exporter
            }
          ];
          scrape_interval = "60s";
          scrape_timeout = "30s";
        }
      ];
    };
    services.nginx.virtualHosts."stationary.ahbk".locations."/grafana/" = {
      proxyPass = "http://localhost:9999";
      proxyWebsockets = true;
    };
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_port = 9999;
          domain = "stationary.ahbk";
          root_url = "http://stationary.ahbk/grafana/";
          serve_from_sub_path = true;
        };
        "auth.anonymous".enabled = true;
        "auth.basic".enabled = false;
      };
      provision.datasources = {
        settings.datasources = [
          {
            name = "Prometheus localhost";
            url = "http://localhost:9090";
            type = "prometheus";
            isDefault = true;
          }
        ];
      };
    };
  };
}
