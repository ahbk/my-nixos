{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  cfg = config.my-nixos.sendmail;
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
  options.my-nixos.sendmail =
    with types;
    mkOption {
      description = "Set of users to be configured with sendmail.";
      type = attrsOf (submodule userOpts);
      default = { };
    };

  config = mkIf (eachUser != { }) {

    age.secrets = mapAttrs' (
      user: cfg:
      (nameValuePair "mail-plain-${user}" {
        file = ../secrets/mail-plain-${user}.age;
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
      accounts = mapAttrs (user: cfg: {
        host = "mail.ahbk.se";
        auth = true;
        user = "${user}@ahbk.se";
        from = "${user}@ahbk.se";
        passwordeval = "${pkgs.coreutils}/bin/cat ${config.age.secrets."mail-plain-${user}".path}";
      }) eachUser;
    };
  };
}
