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
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "stationary";
    };
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
                "backup.ahbk:${toString restic.port}"
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
            target = [ "__param_target__" ];
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
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              source_labels = [ "__param_target" ];
              regex = "https?://([^/:]+).*";
              target_label = "domain";
            }
            {
              target_label = "__address__";
              replacement = "stationary.ahbk:9115";
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
      configuration = {
        auth_enabled = false;
        pattern_ingester = {
          enabled = true;
        };

        server = {
          http_listen_port = ids.loki.port;
          grpc_listen_port = 0;
        };

        common = {
          ring = {
            instance_addr = "127.0.0.1";
            kvstore = {
              store = "memberlist";
            };
          };
          replication_factor = 1;
          path_prefix = "/var/lib/loki/working";
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
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
            cache_ttl = "24h";
          };
        };

        limits_config = {
          retention_period = "30d";
        };
        memberlist = {
          bind_addr = [ "0.0.0.0" ];
          bind_port = 7946;
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
