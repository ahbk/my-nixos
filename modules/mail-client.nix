{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.ahbk.mailClient;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options = {
      enable = mkEnableOption (mdDoc "Configure a mail client for user") // {
        default = true;
      };
    };
  };
in {
  options.ahbk.mailClient = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (eachUser != {}) {

    age.secrets = mapAttrs' (user: cfg: (
      nameValuePair "linux-passwd-plain-${user}" {
        file = ../secrets/linux-passwd-plain-${user}.age;
        owner = user;
        group = user;
      })) eachUser;

    programs.msmtp = {
      enable = true;
      defaults = {
        port = 587;
        tls = true;
        logfile = "~/.msmtp.log";
      };
      accounts = mapAttrs (user: cfg: ({
        host = "mail.ahbk.se";
        auth = true;
        user = "${user}@ahbk.se";
        from = "${user}@ahbk.se";
        passwordeval = "${pkgs.coreutils}/bin/cat ${config.age.secrets."linux-passwd-plain-${user}".path}";
      })) eachUser;
    };
  };
}
