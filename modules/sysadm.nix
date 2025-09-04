{
  config,
  hosts,
  lib,
  host,
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
      };

      sops.age = {
        keyFile = lib.mkDefault "/keys/host-${host.name}";
        sshKeyPaths = [ ];
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
          path = "/keys/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    }

    (mkIf (cfg.rescueMode) {
      users.mutableUsers = false;
      users.users.root = {
        hashedPassword = "$2b$05$EHOSTmw3WZeWt27ZhQC4c.kaZksxtu0YSYgrImApwxYjuXfonvSUO";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alex@ahbk.se"
        ];
      };
      services.openssh.settings = {
        PermitRootLogin = mkForce "yes";
      };
    })
  ];
}
