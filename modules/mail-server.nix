{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.my-nixos.mailServer;
in
{

  options = {
    my-nixos.mailServer = {
      enable = mkEnableOption "mail server.";
    };
  };

  config = mkIf (cfg.enable) {
    services.postfix.transport = ''
      esse.nu smtp:
    '';
    mailserver = {
      enable = true;
      fqdn = "mail.ahbk.se";
      dkimSelector = "ahbk";
      domains = [
        "ahbk.se"
        "esse.nu"
      ];

      loginAccounts = {
        "alex@ahbk.se" = {
          hashedPasswordFile = config.users.users.alex.hashedPasswordFile;
          aliases = [
            "postmaster@ahbk.se"
            "abuse@ahbk.se"
            "admin@ahbk.se"
            "hej@ahbk.se"
          ];
        };
      };

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
