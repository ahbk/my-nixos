{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.my-nixos.postgresql;
  eachCfg = filterAttrs (user: cfg: cfg.ensure) cfg;
  userOpts = {
    options = {
      ensure = mkOption {
        description = "Ensure a postgresql database for the user.";
        default = true;
        type = types.bool;
      };
    };
  };
in
{
  options = {
    my-nixos.postgresql = mkOption {
      type = types.attrsOf (types.submodule userOpts);
      default = { };
      description = "Specification of one or more postgresql user/database pair to setup";
    };
  };

  config = mkIf (eachCfg != { }) {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_14;
      ensureDatabases = mapAttrsToList (user: cfg: user) eachCfg;
      ensureUsers = mapAttrsToList (user: cfg: {
        name = user;
        ensureDBOwnership = true;
      }) eachCfg;
    };
  };
}
