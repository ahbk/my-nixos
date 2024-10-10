{ pkgs, config, ... }:
let
  users = import ../users.nix;
  sites = import ../sites.nix;
in
{
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  services.netdata.enable = true;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.nginx.virtualHosts."stationary.ahbk".locations."/netdata/" = {
    proxyPass = "http://localhost:19999/";
  };

  services.prometheus.exporters.blackbox = {
    enable = true;
    configFile = pkgs.writeTextFile {
      name = "prometheus-exporters-blackbox";
      text = ''
        modules:
          http_2xx:
            prober: http
            timeout: 5s
            http:
              valid_http_versions: [ "HTTP/1.1", "HTTP/2" ]
              valid_status_codes: []
      '';
    };
  };
  services.prometheus = {
    enable = true;
    scrapeConfigs = with config.services.prometheus.exporters; [
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

  services.invoiceplane = {
    webserver = "nginx";
    sites."invoiceplane.ahbk" = {
      enable = true;
      settings = {
        DISABLE_SETUP = true;
      };
    };
  };

  services.kresd = {
    enable = true;
    listenPlain = [ "10.0.0.1:53" ];
    extraConfig = ''
      modules = { 'hints > iterate' }
      hints['invoiceplane.ahbk'] = '10.0.0.1'
      hints['stationary.ahbk'] = '10.0.0.1'
      hints['glesys.ahbk'] = '10.0.0.3'
      hints['laptop.ahbk'] = '10.0.0.2'
      hints['phone.ahbk'] = '10.0.0.4'
      hints['backup.ahbk'] = '10.0.0.1'
    '';
  };

  networking = {
    useDHCP = false;
    enableIPv6 = false;
    firewall = {
      logRefusedConnections = false;
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };

  systemd.network = {
    enable = true;
    networks."10-enp3s0" = {
      matchConfig.Name = "enp3s0";
      networkConfig.DHCP = "ipv4";
    };
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

  services.nginx.virtualHosts."stationary.ahbk".locations."/grafana/" = {
    proxyPass = "http://localhost:9999";
    proxyWebsockets = true;
  };

  my-nixos = with users; {
    users = {
      inherit alex frans;
    };
    shell.alex.enable = true;
    hm.alex.enable = true;
    ide.alex = {
      enable = true;
      postgresql = true;
      mysql = true;
    };

    backup.local = {
      enable = true;
      target = "backup.ahbk";
      server = true;
    };

    mailserver.monitor = true;

    glesys.updaterecord = {
      enable = true;
      recordid = "3357682";
      cloudaccount = "cl44748";
      device = "enp3s0";
    };

    fail2ban = {
      enable = true;
      ignoreIP = [
        "10.0.0.0/24"
        "ahbk.se"
        "stationary.ahbk.se"
        "shadowserver.org"
      ];
    };

    wireguard.wg0.enable = true;

    sendmail.alex.enable = true;

    nginx = {
      enable = true;
      email = alex.email;
    };

    wordpress.sites."test.esse.nu" = sites."test.esse.nu";
  };
}
