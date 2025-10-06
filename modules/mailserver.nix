{
  config,
  inputs,
  lib,
  lib',
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
in
{
  imports = [
    inputs.nixos-mailserver.nixosModules.default
  ];

  options.my-nixos.mailserver = with types; {
    enable = mkEnableOption "mailserver on this host";
    domain = mkOption {
      description = "The domain name of this mailserver.";
      type = str;
    };
    dkimSelector = mkOption {
      description = "Label for the DKIM key currently in use.";
      type = str;
    };
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

      my-nixos.redis.servers.rspamd.enable = true;

      my-nixos.preserve.directories = with config.mailserver; [
        dkimKeyDirectory
        mailDirectory
        sieveDirectory
      ];

      sops.secrets =
        lib'.mergeAttrs (user: _: {
          "${user}/mail-sha512" = {
            sopsFile = ../enc/user-${user}.yaml;
            owner = user;
            group = user;
            restartUnits = [
              "dovecot2.service"
              "postfix.service"
            ];
          };
        }) cfg.users
        // {
          "dmarc-reports/mail-sha512" = {
            sopsFile = ../enc/service-dmarc-reports.yaml;
            restartUnits = [
              "dovecot2.service"
              "postfix.service"
            ];
          };
        };

      mailserver = {
        enable = true;
        stateVersion = 3;
        fqdn = "mail.${cfg.domain}";
        dkimSelector = cfg.dkimSelector;
        domains = mapAttrsToList (domain: _: domain) mailboxDomains;
        domainsWithoutMailbox = mapAttrsToList (domain: _: domain) relayDomains;
        enableSubmissionSsl = false;
        redis.configureLocally = false;
        mailboxes = {
          Drafts = {
            auto = "subscribe";
            specialUse = "Drafts";
          };
          Junk = {
            auto = "subscribe";
            specialUse = "Junk";
          };
          Sent = {
            auto = "subscribe";
            specialUse = "Sent";
          };
          Trash = {
            auto = "subscribe";
            specialUse = "Trash";
          };
        };

        loginAccounts = mkMerge [
          (mapAttrs' (user: userCfg: {
            name = config.my-nixos.users.${user}.email;
            value = {
              inherit (userCfg) catchAll;
              hashedPasswordFile = config.sops.secrets."${user}/mail-sha512".path;
              aliases = config.my-nixos.users.${user}.aliases;
            };
          }) cfg.users)
          {
            "dmarc-reports@${cfg.domain}" = {
              hashedPasswordFile = config.sops.secrets."dmarc-reports/mail-sha512".path;
              catchAll = [ ];
              aliases = [ ];
            };
          }
        ];

        certificateScheme = "acme-nginx";
      };

      services = {

        #fail2ban.jails = {
        #  postfix.settings = {
        #    filter = "postfix[mode=aggressive]";
        #  };
        #  dovecot.settings = {
        #    filter = "dovecot[mode=aggressive]";
        #  };
        #};

        postfix = {
          origin = cfg.domain;
          networks = [
            "10.0.0.0/24"
            "127.0.0.1/32"
            "[::1]/128"
          ];
          transport =
            let
              transportsList = mapAttrsToList (domain: cfg: "${domain} smtp:") relayDomains;
              transportsCfg = concatStringsSep "\n" transportsList;
            in
            transportsCfg;
        };
      };
    })
  ];
}
