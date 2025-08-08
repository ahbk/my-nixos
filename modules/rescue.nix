{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkForce;
  cfg = config.my-nixos.rescue;
in
{
  options.my-nixos.rescue = {
    enable = mkEnableOption "insecure rescue mode.";
  };

  config = mkIf (cfg.enable) {
    users.users.root = {
      hashedPassword = "$2b$05$EHOSTmw3WZeWt27ZhQC4c.kaZksxtu0YSYgrImApwxYjuXfonvSUO";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alex@ahbk.se"
      ];
    };
    services.openssh.settings.PermitRootLogin = mkForce "yes";
  };
}
