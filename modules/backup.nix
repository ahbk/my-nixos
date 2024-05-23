{ config
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.backup;
in {
  options = {
    ahbk.backup = with types; {
      enable = mkEnableOption (mdDoc "Configure backup for this host");
      host = mkOption {
        type = str;
      };
      paths = mkOption {
        type = listOf str;
        default = [];
      };
      user = mkOption {
        type = str;
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

  config = mkIf cfg.enable {
    age.secrets."linux-passwd-plain-${cfg.user}" = {
      file = ../secrets/linux-passwd-plain-${cfg.user}.age;
      owner = cfg.user;
      group = cfg.user;
    };
    services.restic.backups.${cfg.host} = {
      inherit (cfg) paths exclude repository;
      initialize = true;
      user = "backup";
      passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
      timerConfig = {
        OnCalendar = "daily";
      };
    };
  };
}
