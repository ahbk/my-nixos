{ config, lib, ... }:

with lib;

let
  cfg = config.my-nixos.backup;
  eachTarget = filterAttrs (user: cfg: cfg.enable) cfg;
  targetOpts = {
    options = with types; {
      enable = mkEnableOption "backup target";
      paths = mkOption {
        description = "List of paths to backup";
        example = [
          /home/alex/.bash_history
          /home/alex/.local/share/qutebrowser/history.sqlite
        ];
        type = listOf str;
        default = [ ];
      };
      exclude = mkOption {
        description = "List of paths to not backup";
        example = [ /home/alex/.cache ];
        type = listOf str;
        default = [ ];
      };
    };
  };
in
{
  options = {
    my-nixos.backup =
      with types;
      mkOption {
        type = attrsOf (submodule targetOpts);
        default = { };
        description = "Specification of one or more backup targets";
      };
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

    services.restic.backups = mapAttrs (target: cfg: {
      inherit (cfg) paths exclude;
      repository = "sftp:backup@${target}:repository";
      initialize = true;
      user = "root";
      passwordFile = config.age.secrets."linux-passwd-plain-backup".path;
      extraOptions = [ "sftp.command='ssh backup@${target} -i /home/backup/.ssh/id_ed25519 -s sftp'" ];
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 01:00:00";
        Persistent = true;
      };
    }) eachTarget;
  };
}
