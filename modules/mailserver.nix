{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    filterAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.my-nixos.mailserver;
  relayDomains = filterAttrs (domain: cfg: !cfg.mailbox) cfg.domains;
  mailboxDomains = filterAttrs (domain: cfg: cfg.mailbox) cfg.domains;
  lib' = (import ../lib.nix) { inherit lib pkgs; };
in
{

  options.my-nixos.mailserver = with types; {
    enable = mkEnableOption "mail server";
    users = mkOption {
      description = "Configure user accounts.";
      type = attrsOf (submodule {
        options = {
          enable = (mkEnableOption "this user") // {
            default = true;
          };
          catchAll = mkOption {
            description = "Make the user recipient of a whole domain.";
            type = listOf str;
            default = [ ];
          };
        };
      });
    };
    domains = mkOption {
      description = "List of domains to manage.";
      type = attrsOf (submodule {
        options = {
          mailbox = mkOption {
            description = "Enable if this host is the domain's final destination.";
            type = bool;
          };
        };
      });
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {

      sops.secrets.users = lib'.mergeAttrs (user: _: {
        "${user}/mail-hashed" = {
          sopsFile = ../secrets/users.yaml;
          owner = user;
          group = user;
        };
      }) cfg.users;

      mailserver = {
        enable = true;
        fqdn = "mail.ahbk.se";
        dkimSelector = "ahbk";
        domains = mapAttrsToList (domain: _: domain) mailboxDomains;
        relayDomains = mapAttrsToList (domain: cfg: domain) relayDomains;
        enableSubmissionSsl = false;

        loginAccounts = mapAttrs' (user: userCfg: {
          name = config.my-nixos.users.${user}.email;
          value = {
            inherit (userCfg) catchAll;
            hashedPasswordFile = config.sops.secrets.users."${user}/mail-hashed".path;
            aliases = config.my-nixos.users.${user}.aliases;
          };
        }) cfg.users;

        certificateScheme = "acme-nginx";
      };

      services = {

        fail2ban.jails = {
          postfix.settings = {
            filter = "postfix[mode=aggressive]";
          };
          dovecot.settings = {
            filter = "dovecot[mode=aggressive]";
          };
        };

        postfix = {
          origin = "ahbk.se";
          networks = [
            "10.0.0.0/24"
            "127.0.0.1/32"
            "46.246.47.6/32"
            "[::1]/128"
            "[2a02:752:0:18::37]/128"
            "[fe80::10e0:d7ff:fe9c:3f01]/128"
          ];
          transport =
            let
              transportsList = mapAttrsToList (domain: cfg: "${domain} smtp:") relayDomains;
              transportsCfg = concatStringsSep "\n" transportsList;
            in
            transportsCfg;
        };

        prometheus.exporters = {
          postfix = {
            enable = true;
          };
          rspamd = {
            enable = true;
          };
        };

        dovecot2.extraConfig = ''
          service stats {
            inet_listener http {
              port = ${toString config.services.prometheus.exporters.dovecot.port}
            }
          }

          metric auth_success {
            filter = (event=auth_request_finished AND success=yes)
          }

          metric imap_command {
            filter = event=imap_command_finished
            group_by = cmd_name tagged_reply_state
          }

          metric smtp_command {
            filter = event=smtp_server_command_finished
            group_by = cmd_name status_code duration:exponential:1:5:10
          }

          metric mail_delivery {
            filter = event=mail_delivery_finished
            group_by = duration:exponential:1:5:10
          }
        '';

        # nixos-mailserver configures this redis instance,
        # we just add a log identity
        redis.servers.rspamd = {
          settings = {
            syslog-ident = "redis-rspamd";
          };
        };

        restic.backups.local.paths = with config.mailserver; [
          dkimKeyDirectory
          mailDirectory
        ];

        nginx.virtualHosts.rspamd = {
          serverName = "glesys.ahbk";
          locations = {
            "/rspamd/" = {
              proxyPass = "http://unix:/run/rspamd/worker-controller.sock:/";
            };
          };
        };
      };
    })
  ];
}
