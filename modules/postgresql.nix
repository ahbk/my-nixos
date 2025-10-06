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
    mkDefault
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.postgresql;
  eachCfg = filterAttrs (user: cfg: cfg.ensure) cfg;
in
{
  options.my-nixos.postgresql = mkOption {
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        {
          options = {
            ensure = mkOption {
              description = "Ensure a postgresql database for the user.";
              default = true;
              type = types.bool;
            };
            name = mkOption {
              description = "Name of the postgresql database/user-pair.";
              type = types.nullOr types.str;
              default = null;
            };
          };
          config = {
            name = mkDefault (config._module.args.name or null);
          };
        }
      )
    );
    default = { };
    description = "Specification of one or more postgresql user/database pair to setup";
  };

  config = mkIf (eachCfg != { }) {
    preservation.preserveAt."/srv/database" = {
      directories = [
        {
          directory = "/var/lib/postgresql";
          user = "postgres";
          group = "postgres";
        }
      ];
    };
    services = {
      postgresql = {
        extensions =
          ps: with ps; [
            postgis
            pg_repack
          ];
        enable = true;
        package = pkgs.postgresql_17;
        ensureDatabases = mapAttrsToList (user: cfg: cfg.name) eachCfg;
        ensureUsers = mapAttrsToList (user: cfg: {
          name = cfg.name;
          ensureDBOwnership = true;
        }) eachCfg;
      };
    };
  };
}
