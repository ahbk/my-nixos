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
      extraOptions = [
        "sftp.command='ssh backup@10.0.0.1 -i /home/backup/.ssh/id_ed25519 -s sftp'"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 01:00:00";
        Persistent = true;
      };
    }) eachTarget;
  };
}
