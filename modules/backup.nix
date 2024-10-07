{ config, lib, ... }:

let
  inherit (lib)
    filterAttrs
    mapAttrs
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
      paths = mkOption {
        description = ''Paths to backup.'';
        example = [
          /home/alex/.bash_history
          /home/alex/.local/share/qutebrowser/history.sqlite
        ];
        type = listOf str;
        default = [ ];
      };
      exclude = mkOption {
        description = ''Paths to exclude from backup.'';
        example = [ /home/alex/.cache ];
        type = listOf str;
        default = [ ];
      };
      pruneOpts = mkOption {
        description = ''
          A list of options (--keep-\* et al.) for 'restic forget
          --prune', to automatically prune old snapshots.  The
          'forget' command is run *after* the 'backup' command, so
          keep that in mind when constructing the --keep-\* options.
        '';
        type = listOf str;
        default = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
      };
      timerConfig = mkOption {
        description = ''
          When to run the backup. See {manpage}`systemd.timer(5)` for
          details. If null no timer is created and the backup will only
          run when explicitly started.
        '';
        type = anything;
        default = {
          OnCalendar = "01:00";
          Persistent = true;
        };
      };
      privateKeyFile = mkOption {
        description = ''
          Location of the private key file used to connect with target.
          Match with a public key in `my-nixos.users.backup.keys`.
        '';
        type = str;
        default = "/home/backup/.ssh/id_ed25519";
      };
    };
  };
in
{
  options.my-nixos.backup = mkOption {
    type = types.attrsOf (types.submodule targetOpts);
    default = { };
    description = ''Definition of backup targets.'';
  };

  config = mkIf (eachTarget != { }) {

    age.secrets."linux-passwd-plain-backup" = {
      file = ../secrets/linux-passwd-plain-backup.age;
      owner = "backup";
      group = "backup";
    };

    services.openssh.knownHosts = mapAttrs (target: cfg: {
      publicKeyFile = ../keys/ssh-host-${target}.pub;
    }) eachTarget;

    services.prometheus.exporters.restic = {
      enable = true;
      passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
    };

    services.restic.backups = mapAttrs (target: targetCfg: {
      inherit (targetCfg)
        paths
        exclude
        pruneOpts
        timerConfig
        ;
      repository = "sftp:backup@${target}:repository";
      initialize = true;
      user = "root";
      passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
      extraOptions = [ "sftp.command='ssh backup@${target} -i ${targetCfg.privateKeyFile} -s sftp'" ];
    }) eachTarget;
  };
}
