{ config, pkgs, lib, inputs, system, ... }:

with lib;

let
  cfg = config.ahbk.odoo;
  format = pkgs.formats.ini {};

  pkgs-wkhtmltopdf = import inputs.nixpkgs-wkhtmltopdf { inherit system; };

  mkNixPak = inputs.nixpak.lib.nixpak {
    inherit (pkgs) lib;
    inherit pkgs;
  };

  wkhtmltopdf = (mkNixPak {
    config = {
      app.package = pkgs-wkhtmltopdf.wkhtmltopdf;
      app.binPath = "bin/wkhtmltopdf";
      bubblewrap = {
        bind.rw = [ "/tmp" ];
      };
    };
  }).config.script;
in
{
  options = {
    ahbk.odoo = {
      enable = mkEnableOption (lib.mdDoc "odoo");

      package = mkOption {
        type = types.package;
        default = pkgs.odoo;
        defaultText = literalExpression "pkgs.odoo";
        description = lib.mdDoc "Odoo package to use.";
      };

      ssl = mkOption {
        type = types.bool;
      };

      addons = mkOption {
        type = with types; listOf package;
        default = [];
        example = literalExpression "[ pkgs.odoo_enterprise ]";
        description = lib.mdDoc "Odoo addons.";
      };

      settings = mkOption {
        type = format.type;
        default = {};
        description = lib.mdDoc ''
          Odoo configuration settings. For more details see <https://www.odoo.com/documentation/15.0/administration/install/deploy.html>
        '';
        example = literalExpression ''
          options = {
            db_user = "odoo";
            db_password = "odoo";
          };
        '';
      };

      domain = mkOption {
        type = with types; nullOr str;
        description = lib.mdDoc "Domain to host Odoo with nginx";
        default = null;
      };
    };
  };

  config = mkIf (cfg.enable) (let
    cfgFile = format.generate "odoo.cfg" cfg.settings;
  in {

    environment.systemPackages = [ cfg.package ];

    services.nginx = mkIf (cfg.domain != null) {
      upstreams = {
        odoo.servers = {
          "127.0.0.1:8069" = {};
        };

        odoochat.servers = {
          "127.0.0.1:8072" = {};
        };
      };

      virtualHosts."${cfg.domain}" = {
        forceSSL = cfg.ssl;
        enableACME = cfg.ssl;
        extraConfig = ''
          proxy_read_timeout 720s;
          proxy_connect_timeout 720s;
          proxy_send_timeout 720s;

          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Real-IP $remote_addr;
        '';

        locations = {
          "/longpolling" = {
            proxyPass = "http://odoochat";
          };

          "/" = {
            proxyPass = "http://odoo";
            extraConfig = ''
              proxy_redirect off;
            '';
          };
        };
      };
    };

    ahbk.odoo.settings.options = {
      proxy_mode = cfg.domain != null;
    };

    users.users.odoo = {
      isSystemUser = true;
      group = "odoo";
    };
    users.groups.odoo = {};

    systemd.services.odoo = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "postgresql.service" ];

      # pg_dump and pdf generation
      path = [
        config.services.postgresql.package
        wkhtmltopdf
      ];

      # wkhtmltopdf requires this to be set
      environment = {
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/dev/null";
      };

      requires = [ "postgresql.service" ];
      script = ''
        HOME=$STATE_DIRECTORY \
        XDG_RUNTIME_DIR=$STATE_DIRECTORY \
        ${cfg.package}/bin/odoo \
        ${optionalString (cfg.addons != []) "--addons-path=${concatMapStringsSep "," escapeShellArg cfg.addons}"} \
        -c ${cfgFile}
      '';

      serviceConfig = {
        DynamicUser = true;
        User = "odoo";
        StateDirectory = "odoo";
      };
    };

    ahbk.postgresql.odoo.ensure = true;
  });
}
