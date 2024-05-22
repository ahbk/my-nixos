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
      exclude = mkOption {
        type = listOf str;
        default = [];
      };
      repository = mkOption {
        type = path;
      };
    };
  };

  config = mkIf cfg.enable {
    age.secrets."linux-passwd-plain-frans" = {
      file = ../secrets/linux-passwd-plain-frans.age;
      owner = "root";
      group = "root";
    };
    services.restic.backups.${cfg.host} = {
      inherit (cfg) paths exclude repository;
      initialize = true;
      passwordFile = config.age.secrets."linux-passwd-plain-frans".path;
      timerConfig = {
        OnCalendar = "daily";
      };
    };
  };
}
