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

    sops.secrets = mapAttrs' (
      user: cfg:
      (nameValuePair "${user}/mail" {
        sopsFile = ../enc/user-${user}.yaml;
        owner = user;
        group = user;
      })
    ) eachUser;

    programs.msmtp = {
      enable = true;
      defaults = {
        port = 587;
        host = "helsinki.km";
        tls = true;
        logfile = "~/.msmtp.log";
      };
      accounts = mapAttrs (user: cfg: {
        host = "mail.kompismoln.se";
        auth = true;
        user = "${user}@kompismoln.se";
        from = "${user}@kompismoln.se";
        passwordeval = "${pkgs.coreutils}/bin/cat ${config.sops.secrets."${user}/mail".path}";
      }) eachUser;
    };
  };
}
