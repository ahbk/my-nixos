{
  config,
  lib,
  ids,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.my-nixos.sysadm;
in
{
  options.my-nixos.sysadm = {
    keyservice = mkEnableOption "user keyservice";
  };

  config = mkIf (cfg.keyservice) {
    users.users.keyservice = {
      description = "Key Management Service User";
      isSystemUser = true;
      home = /dev/null;
      shell = /dev/null;

      openssh.authorizedKeys.keyFiles = [
        ../users/keyservice-ssh-key.pub
      ];
      uid = ids.keyservice.uid;
    };

    users.groups.keyservice = {
      gid = ids.keyservice.uid;
    };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
      };

      extraConfig = ''
        Match User keyservice
          PermitTTY no
          PermitX11Forwarding no
          PermitAgentForwarding no
          PermitPortForwarding no
      '';
    };

    # This may be neeeded but maybe not is 'f' the correct designation?
    systemd.tmpfiles.rules = [
      "f /srv/storage/host/keys.txt 0600 keyservice keyservice -"
    ];

    # This is cute. The thing I this to do is
    # 1) receive an age key and check if it matches first or second key in /srv/storage/host/keys.txt
    # 2) receive an age key and add it to the top of /srv/storage/host/keys.txt
    #    while removing all keys but two (leaving two functional keys at all times)
    # 3) check if a luks key is able to unlock /dev/sda3
    #    push a key to luks
    #    remove a key to luks
    environment.etc."keyservice/key-update-wrapper.sh" = {
      text = ''
        #!/bin/bash
        set -euo pipefail

        # Log all operations
        exec > >(tee -a /var/lib/keyservice/logs/operations.log)
        exec 2>&1

        echo "$(date): Key update operation started by $(whoami) from $SSH_CLIENT"

        # Parse the SSH command
        case "$SSH_ORIGINAL_COMMAND" in
          "update-ssl-cert"*)
            /var/lib/keyservice/scripts/update-ssl-cert.sh "$@"
            ;;
          "update-api-key"*)
            /var/lib/keyservice/scripts/update-api-key.sh "$@"
            ;;
          "backup-keys")
            /var/lib/keyservice/scripts/backup-keys.sh
            ;;
          "list-keys")
            /var/lib/keyservice/scripts/list-keys.sh
            ;;
          *)
            echo "Unauthorized command: $SSH_ORIGINAL_COMMAND"
            exit 1
            ;;
        esac

        echo "$(date): Operation completed successfully"
      '';
      mode = "0755";
      user = "keyservice";
      group = "keys";
    };

    # Copy wrapper script to keyservice home
    system.activationScripts.keyservice-setup = ''
      cp /etc/keyservice/key-update-wrapper.sh /var/lib/keyservice/scripts/
      chown keyservice:keys /var/lib/keyservice/scripts/key-update-wrapper.sh
      chmod 755 /var/lib/keyservice/scripts/key-update-wrapper.sh
    '';

    # Security hardening
    security.sudo.extraRules = [
      {
        users = [ "keyservice" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/cryptsetup open --test-passphrase *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

  };
}
