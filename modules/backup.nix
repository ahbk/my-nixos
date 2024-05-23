{ config
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.backup;
  eachTarget = filterAttrs (user: cfg: cfg.enable) cfg;
  targetOpts = {
    options = with types; {
      enable = mkEnableOption (mdDoc "Configure backup for this host");
      paths = mkOption {
        type = listOf str;
        default = [];
      };
      exclude = mkOption {
        type = listOf str;
        default = [];
      };
      repository = mkOption {
        type = str;
      };
    };
  };
in {
  options = {
    ahbk.backup = with types; mkOption {
      type = attrsOf (submodule targetOpts);
      default = {};
      description = mdDoc "Specification of one or more backup targets";
    };
  };

  config = mkIf (eachTarget != {}) {
    age.secrets."linux-passwd-plain-backup" = {
      file = ../secrets/linux-passwd-plain-backup.age;
      owner = "backup";
      group = "backup";
    };
    services.restic.backups = mapAttrs (target: cfg: {
      inherit (cfg) paths exclude repository;
      initialize = true;
      user = "root";
      passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    }) eachTarget;
  };
}
