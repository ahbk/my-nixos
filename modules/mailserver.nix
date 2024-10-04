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
    mkOption
    types
    ;

  cfg = config.my-nixos.mailserver;
  relayDomains = filterAttrs (domain: cfg: !cfg.mailbox) cfg.domains;
  mailboxDomains = filterAttrs (domain: cfg: cfg.mailbox) cfg.domains;
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

  config = mkIf (cfg.enable) {

    services.postfix = {
      origin = "ahbk.se";
      transport =
        let
          transportsList = mapAttrsToList (domain: cfg: "${domain} smtp:") relayDomains;
          transportsCfg = concatStringsSep "\n" transportsList;
        in
        transportsCfg;
    };

    age.secrets = mapAttrs' (user: _: {
      name = "mail-hashed-${user}";
      value = {
        file = ../secrets/mail-hashed-${user}.age;
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
          hashedPasswordFile = config.age.secrets."mail-hashed-${user}".path;
          aliases = config.my-nixos.users.${user}.aliases;
        };
      }) cfg.users;

      certificateScheme = "acme-nginx";
    };

    # nixos-mailserver configures this redis instance,
    # we just add a log identity
    services.redis.servers.rspamd = {
      settings = {
        syslog-ident = "redis-rspamd";
      };
    };

    my-nixos.backup."backup.ahbk".paths = with config.mailserver; [
      dkimKeyDirectory
      mailDirectory
    ];

    my-nixos.monit.config = ''
      check process postfix with pidfile /var/lib/postfix/queue/pid/master.pid
          start program = "${pkgs.systemd}/bin/systemctl start postfix"
          stop program = "${pkgs.systemd}/bin/systemctl stop postfix"
          if failed port 25 protocol smtp for 5 cycles then restart

      check process dovecot with pidfile /var/run/dovecot2/master.pid
          start program = "${pkgs.systemd}/bin/systemctl start dovecot2"
          stop program = "${pkgs.systemd}/bin/systemctl stop dovecot2"
          if failed host ${config.mailserver.fqdn} port 993 type tcpssl sslauto protocol imap for 5 cycles then restart

      check process rspamd with matching "rspamd: main process"
          start program = "${pkgs.systemd}/bin/systemctl start rspamd"
          stop program = "${pkgs.systemd}/bin/systemctl stop rspamd"
    '';

    services.fail2ban.jails = {
      postfix.settings = {
        filter = "postfix[mode=aggressive]";
      };
      dovecot.settings = {
        filter = "dovecot[mode=aggressive]";
      };
    };
  };
}
