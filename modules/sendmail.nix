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
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.sendmail;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;
  lib' = (import ../lib.nix) { inherit lib pkgs; };

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

    sops.secrets.users = lib'.mergeAttrs (user: cfg: {
      "${user}/mail-plain" = {
        sopsFile = ../secrets/users.yaml;
        owner = user;
        group = user;
      };
    }) eachUser;

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
        passwordeval = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.users."${user}/mail-plain".path}";
      }) eachUser;
    };
  };
}
