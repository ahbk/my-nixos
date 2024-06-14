{ config, lib, ... }:

let
  inherit (lib)
    concatStringsSep
    filterAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.mailserver;
  noRelayDomains = filterAttrs (domain: cfg: !cfg.relay) cfg.domains;
in
{

  options.my-nixos.mailserver = with types; {
    enable = mkEnableOption "mail server.";
    users = mkOption {
      description = "List of users to enable server for.";
      type = listOf str;
    };
    domains = mkOption {
      description = "List of domains to manage.";
      type = attrsOf (submodule {
        options = {
          relay = mkOption {
            description = "Enable if this host is the domain's final destination.";
            type = bool;
          };
        };
      });
    };

  };

  config = mkIf (cfg.enable) {

    services.postfix.transport = let 
      nullTransports = mapAttrsToList (domain: cfg: "${domain} smtp:") noRelayDomains;
      cfg = concatStringsSep "\n" nullTransports;
    in cfg;

    age.secrets = builtins.listToAttrs (builtins.map (user: {
      name = "mail-hashed-${user}";
      value = {
        file = ../secrets/mail-hashed-${user}.age;
        owner = user;
        group = user;
      };
    }) cfg.users);

    mailserver = {
      enable = true;
      fqdn = "mail.ahbk.se";
      dkimSelector = "ahbk";
      domains = mapAttrsToList (domain: _: domain) cfg.domains;

      loginAccounts = builtins.listToAttrs (builtins.map (user: {
        name = "${user}@ahbk.se";
        value = {
          hashedPasswordFile = config.age.secrets."mail-hashed-${user}".path;
          aliases = config.my-nixos.users.${user}.aliases;
        };
      }) cfg.users);

      certificateScheme = "acme-nginx";
    };

    my-nixos.backup."backup.ahbk".paths = with config.mailserver; [
      dkimKeyDirectory
      mailDirectory
    ];

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
