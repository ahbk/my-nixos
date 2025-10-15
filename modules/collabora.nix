{
  lib,
  lib',
  config,
  ...
}:
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
        default = false;
        type = types.bool;
      };
      host = mkOption {
        description = "Public hostname";
        type = types.str;
      };
      allowedHosts = mkOption {
        description = "Accept WOPI from these hosts";
        type = types.listOf types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    my-nixos.tls-certs = [ "km" ];

    services.nginx.virtualHosts.${cfg.host} =
      let
        proxyPass = "http://127.0.0.1:${builtins.toString lib'.ids.collabora.port}";
      in
      {
        forceSSL = true;
        sslCertificate = mkIf cfg.subnet ../domains/km-tls-cert.pem;
        sslCertificateKey = mkIf cfg.subnet config.sops.secrets."km/tls-cert".path;

        enableACME = !cfg.subnet;

        locations = {
          "^~ /browser" = {
            inherit proxyPass;
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "^~ /hosting/discovery" = {
            inherit proxyPass;
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "^~ /hosting/capabilities" = {
            inherit proxyPass;
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "~ ^/(c|l)ool" = {
            inherit proxyPass;
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };

          "~ ^/cool/(.*)/ws$" = {
            priority = 1;
            inherit proxyPass;
            extraConfig = ''
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_set_header Host $host;
              proxy_read_timeout 36000s;
            '';
          };

          "^~ /cool/adminws" = {
            inherit proxyPass;
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
      port = lib'.ids.collabora.port;
      aliasGroups = map (host: {
        host = "https://nextcloud.km";
      }) cfg.allowedHosts;

      settings = {
        ssl = {
          enable = false;
          termination = true;
        };
        net = {
          proto = "IPv4";
          listen = "loopback";
        };
      };
    };
  };
}
