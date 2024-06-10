{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mkOption
    mkIf
    mapAttrsToList
    types
    ;
  cfg = config.my-nixos.mysql;
  eachCfg = filterAttrs (user: cfg: cfg.ensure) cfg;
  userOpts = {
    options = with types; {
      ensure = mkOption {
        description = "Ensure mysql database for the user";
        default = true;
        type = bool;
      };
    };
  };
in
{
  options.my-nixos.mysql =
    with types;
    mkOption {
      type = attrsOf (submodule userOpts);
      default = { };
      description = "Specification of one or more mysql user/database pair to setup";
    };

  config = mkIf (eachCfg != { }) {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;

      ensureDatabases = mapAttrsToList (user: cfg: user) eachCfg;
      ensureUsers = mapAttrsToList (user: cfg: {
        name = user;
        ensurePermissions = {
          "\\`${user}\\`.*" = "ALL PRIVILEGES";
        };
      }) eachCfg;
    };
  };
}
