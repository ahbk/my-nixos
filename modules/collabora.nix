{ lib, config, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.my-nixos.collabora;
in
{
  options = {
    my-nixos.collabora = {
      enable = mkEnableOption "collabora-online on this server";

      subnet = mkOption {
        description = "Use self-signed certificates";
        type = types.bool;
      };

      host = mkOption {
        description = "Public hostname";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    my-nixos.ahbk-cert.enable = true;

    services.nginx.virtualHosts.${cfg.host} = {
      forceSSL = true;
      sslCertificate = mkIf cfg.subnet config.age.secrets.ahbk-cert.path;
      sslCertificateKey = mkIf cfg.subnet config.age.secrets.ahbk-cert-key.path;
      enableACME = !cfg.subnet;

      locations = {
        "^~ /browser" = {
          proxyPass = "http://127.0.0.1:9980";
          extraConfig = ''
            proxy_set_header Host $host;
          '';
        };
        "^~ /hosting/discovery" = {
          proxyPass = "http://127.0.0.1:9980";
          extraConfig = ''
            proxy_set_header Host $host;
          '';
        };
        "^~ /hosting/capabilities" = {
          proxyPass = "http://127.0.0.1:9980";
          extraConfig = ''
            proxy_set_header Host $host;
          '';
        };
        "~ ^/(c|l)ool" = {
          proxyPass = "http://127.0.0.1:9980";
          extraConfig = ''
            proxy_set_header Host $host;
          '';
        };

        "~ ^/cool/(.*)/ws$" = {
          priority = 1;
          proxyPass = "http://127.0.0.1:9980";
          extraConfig = ''
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 36000s;
          '';
        };

        "^~ /cool/adminws" = {
          proxyPass = "http://127.0.0.1:9980";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_read_timeout 36000s;
          '';
        };
      };
    };

    services.collabora-online = {
      enable = true;
      settings = {
        ssl = {
          enable = false;
          termination = true;
        };
      };
    };
  };
}
