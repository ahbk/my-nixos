{ config, lib, ... }:
let
  inherit (lib)
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkForce
    ;
  cfg = config.my-nixos.sysadm;
  hosts = import ../hosts.nix;
in
{
  options.my-nixos.sysadm = {
    rescueMode = mkEnableOption "insecure rescue mode.";
  };

  config = mkMerge [
    {
      programs.ssh.knownHosts = mapAttrs (host: cfg: {
        hostNames = [
          "${host}.kompismoln.se"
          "${host}.km"
          cfg.address
        ];
        publicKeyFile = ../keys/${host}-ssh-host-key.pub;
      }) hosts;

      services.openssh.hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/etc/ssh/ssh_host_ed25519_key-";
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
