{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.ahbk.mysql;
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
    ahbk.mysql = mkOption {
      type = types.attrsOf (types.submodule userOpts);
      default = {};
      description = mdDoc "Specification of one or more mysql user/database pair to setup";
    };
  };

  config = mkIf (eachCfg != {}) {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;

      ensureDatabases = mapAttrsToList (user: cfg: user) eachCfg;
      ensureUsers = mapAttrsToList (user: cfg: {
        name = user;
        ensurePermissions = { "\\`${user}\\`.*" = "ALL PRIVILEGES"; };
      }) eachCfg;
    };

  };
}
