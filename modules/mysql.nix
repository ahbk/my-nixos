{ config
, pkgs
, lib
, ...
}:

with lib;

let
  cfg = config.my-nixos.mysql;
  eachCfg = filterAttrs (user: cfg: cfg.ensure) cfg;
  userOpts = {
    options = {
      ensure = mkOption {
        description = "Ensure mysql database for the user";
        default = true;
        type = types.bool;
      };
    };
  };
in {
  options = {
    my-nixos.mysql = mkOption {
      type = types.attrsOf (types.submodule userOpts);
      default = {};
      description = "Specification of one or more mysql user/database pair to setup";
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
