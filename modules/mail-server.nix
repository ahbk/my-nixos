{ config
, lib
, ...
}:

with lib;

let
  cfg = config.my-nixos.mailServer;
in {

  options = {
    my-nixos.mailServer = {
      enable = mkEnableOption "mail server.";
    };
  };

  config = mkIf (cfg.enable) {
    mailserver = {
      enable = true;
      fqdn = "mail.ahbk.se";
      domains = [ "ahbk.se" ];

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
  };
}

