{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.ahbk.postgresql;
  eachCfg = filterAttrs (user: cfg: cfg.ensure) cfg;
  userOpts = {
    options = {
      ensure = mkOption {
        default = true;
        type = types.bool;
      };
    };
  };
in {
  options = {
    ahbk.postgresql = mkOption {
      type = types.attrsOf (types.submodule userOpts);
      default = {};
      description = mdDoc "Specification of one or more postgresql user/database pair to setup";
    };
  };

  config = mkIf (eachCfg != {}) {
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
