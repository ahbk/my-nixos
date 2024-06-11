{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.my-nixos.fail2ban;
in
{
  options.my-nixos.fail2ban = {
    enable = mkEnableOption "site-wide fail2ban";
  };

  config = mkIf cfg.enable {

    services.fail2ban = {
      enable = true;
      maxretry = 1;
      bantime = "24h";
      bantime-increment.enable = true;
      ignoreIP = [
        "10.0.0.0/24"
        "ahbk.se"
        "stationary.ahbk.se"
        "shadowserver.org"
      ];
    };

  };
}
