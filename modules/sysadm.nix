{
  config,
  hosts,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkForce
    ;
  cfg = config.my-nixos.sysadm;
in
{
  options.my-nixos.sysadm = {
    rescueMode = mkEnableOption "insecure rescue mode.";
  };

  config = mkMerge [
    {
      security.sudo = {
        extraConfig = ''
          Defaults lecture = never
        '';
        extraRules = [
          {
            users = [
              "admin"
            ];
            runAs = "root";
            commands = [
              {
                command = "/run/current-system/sw/bin/cryptsetup open --test-passphrase *";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };

      sops.age = {
        keyFile = "/etc/age/keys.txt";
        sshKeyPaths = [ ];

      };

      sops.secrets."ssh-key" = {
        path = "/etc/host/ssh_host_ed25519_key";
        mode = "0400";
      };

      programs.ssh.knownHosts = mapAttrs (host: cfg: {
        hostNames = [
          "${host}.kompismoln.se"
          "${host}.km"
          cfg.address
        ];
        publicKeyFile = ../hosts/${host}/ssh-key.pub;
      }) hosts;

      services.openssh.hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      system.activationScripts = {
        successful-decryption = {
          deps = [ "setupSecrets" ];
          text = ''
            date > /var/lib/last-rebuild
          '';
        };
      };
      my-nixos.preserve = {
        files = [
          {
            file = "/etc/age/keys.txt";
            mode = "0600";
            inInitrd = true;
          }
        ];
      };
    }

    (mkIf (cfg.rescueMode) {
      users.users.root = {
        hashedPassword = "$2b$05$EHOSTmw3WZeWt27ZhQC4c.kaZksxtu0YSYgrImApwxYjuXfonvSUO";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alex@ahbk.se"
        ];
      };
      services.openssh.settings.PermitRootLogin = mkForce "yes";
    })
  ];
}
