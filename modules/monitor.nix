{
  config,
  lib,
  pkgs,
  ids,
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
          job_name = "nginx";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString nginx.port}"
                "stationary.ahbk:${toString nginx.port}"
              ];
              labels = {
                service = "nginx";
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
                "https://klimatkalendern.nu"
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

    users.groups.grafana.gid = config.ids.uids.grafana;

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_port = 9999;
          domain = "stationary.ahbk";
          root_url = "http://stationary.ahbk/grafana/";
          serve_from_sub_path = true;
        };
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

    services.loki = {
      enable = true;
      # The configuration options are typically nested under 'configuration'
      # or directly as attributes. Consult `nixos-option services.loki` for your version.
      # This is a common structure:
      configuration = {
        auth_enabled = false;

        server = {
          http_listen_port = ids.loki.port;
        };

        common = {
          ring = {
            instance_addr = "127.0.0.1";
            kvstore = {
              store = "inmemory";
            };
          };
          replication_factor = 1;
          path_prefix = "/tmp/loki";
        };

        schema_config = {
          configs = [
            {
              from = "2022-01-22";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        storage_config = {
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };

        limits_config = {
          retention_period = "30d"; # e.g., 30 days
          # Enforce limits to prevent Loki from using too much memory/CPU for queries
          # max_query_series = 5000;
          # max_query_parallelism = 32;
        };
      };
    };

    users.users.loki = {
      uid = ids.loki.uid;
      isSystemUser = true;
      group = "loki";
    };
    users.groups.loki.gid = config.users.users.loki.uid;

  };
}
