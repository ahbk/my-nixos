{ config, lib, ... }:

let
  inherit (lib)
    filterAttrs
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.my-nixos.backup;
  eachTarget = filterAttrs (user: cfg: cfg.enable) cfg;
  targetOpts = {
    options = with types; {
      enable = mkEnableOption ''this backup target'';
      target = mkOption {
        type = str;
        default = "localhost";
      };
      port = mkOption {
        type = port;
        default = 7100;
      };
      server = mkEnableOption ''restic rest-server'';
    };
  };
in
{
  options.my-nixos.backup = {
    local = mkOption {
      type = types.submodule targetOpts;
      default = { };
      description = ''Definition of local backup target.'';
    };
    remote = mkOption {
      type = types.submodule targetOpts;
      default = { };
      description = ''Definition of remote backup target.'';
    };
  };

  config = mkIf (eachTarget != { }) {

    age.secrets."linux-passwd-plain-backup" = {
      file = ../secrets/linux-passwd-plain-backup.age;
    };

    services = with config.services.prometheus.exporters; {
      prometheus.scrapeConfigs = [
        {
          job_name = "backup";
          static_configs = [
            {
              targets = [
                "glesys.ahbk:${toString restic.port}"
                "stationary.ahbk:${toString restic.port}"
                "backup.ahbk:${toString cfg.local.port}"
                "laptop.ahbk:${toString restic.port}"
              ];
            }
          ];
        }
      ];

      prometheus.exporters.restic = {
        enable = true;
        repository = "rest:http://${cfg.local.target}:${toString cfg.local.port}/repository";
        passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
      };

      restic = {
        server = {
          enable = cfg.local.server;
          prometheus = true;
          listenAddress = toString cfg.local.port;
          extraFlags = [ "--no-auth" ];
        };

        backups.local = {
          paths = [ ];
          exclude = [ ];
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
          timerConfig = {
            OnCalendar = "01:00";
            Persistent = true;
          };
          repository = "rest:http://${cfg.local.target}:${toString cfg.local.port}/repository";
          initialize = true;
          passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
        };
      };
    };
  };
}
