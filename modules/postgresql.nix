{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.postgresql;
  eachCfg = filterAttrs (user: cfg: cfg.ensure) cfg;
  userOpts = {
    options = {
      ensure =
        with types;
        mkOption {
          description = "Ensure a postgresql database for the user.";
          default = true;
          type = bool;
        };
    };
  };
in
{
  options = {
    my-nixos.postgresql =
      with types;
      mkOption {
        type = attrsOf (submodule userOpts);
        default = { };
        description = "Specification of one or more postgresql user/database pair to setup";
      };
  };

  config = mkIf (eachCfg != { }) {
    services = {
      prometheus.exporters.postgres = {
        enable = true;
        runAsLocalSuperUser = true;
      };
      postgresql = {
        enable = true;
        package = pkgs.postgresql_14;
        ensureDatabases = mapAttrsToList (user: cfg: user) eachCfg;
        ensureUsers = mapAttrsToList (user: cfg: {
          name = user;
          ensureDBOwnership = true;
        }) eachCfg;
      };
    };
  };
}
