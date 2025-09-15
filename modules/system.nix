{
  config,
  host,
  lib,
  ...
}:
let
  inherit (lib)
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
      time.timeZone = "Europe/Stockholm";
      i18n.defaultLocale = "en_US.UTF-8";
      system.stateVersion = host.stateVersion;
      networking.hostName = host.name;
    }

    (mkIf (cfg.rescueMode) {
      users.mutableUsers = false;
      users.users.root = {
        hashedPassword = "$2b$05$EHOSTmw3WZeWt27ZhQC4c.kaZksxtu0YSYgrImApwxYjuXfonvSUO";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alex@ahbk.se"
        ];
      };
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = mkForce "yes";
        };
      };
    })
  ];
}
