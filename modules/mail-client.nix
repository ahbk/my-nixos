{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    types
    mkEnableOption
    mkOption
    mapAttrs
    mapAttrs'
    nameValuePair
    mkIf
    ;
  cfg = config.my-nixos.mailClient;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = {
    options = {
      enable = mkEnableOption "sendmail." // {
        default = true;
      };
    };
  };
in
{
  options.my-nixos.mailClient =
    with types;
    mkOption {
      description = "Set of users to be configured with sendmail.";
      type = attrsOf (submodule userOpts);
      default = { };
    };

  config = mkIf (eachUser != { }) {

    age.secrets = mapAttrs' (
      user: cfg:
      (nameValuePair "linux-passwd-plain-${user}" {
        file = ../secrets/linux-passwd-plain-${user}.age;
        owner = user;
        group = user;
      })
    ) eachUser;

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
