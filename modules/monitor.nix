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
          ];
          valid_status_codes = [ ];
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
            }
          ];
        }
        {
          job_name = "probe websites";
          metrics_path = "/probe";
          params = {
            module = [ "http_2xx" ];
          };
          static_configs = [
            {
              targets = [
                "https://esse.nu"
                "https://chatddx.com"
                "https://sverigesval.org"
                "https://sysctl-user-portal.curetheweb.se"
                "https://ahbk.se"
              ];
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              target_label = "__address__";
              replacement = "stationary.ahbk:9115";
            }
          ];
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
