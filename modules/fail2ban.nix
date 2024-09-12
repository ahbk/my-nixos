{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.my-nixos.fail2ban;
in
{
  options.my-nixos.fail2ban = {
    enable = mkEnableOption "the jails configured with `services.fail2ban.jails`";
    ignoreIP = mkOption {
      default = [ ];
      type = types.listOf types.str;
      example = [ "10.0.0.0/24" "shadowserver.org" ];
      description = ''A list of IP addresses, CIDR masks or DNS hosts not ta ban a host.'';
    };
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      maxretry = 1;
      bantime = "1d";
      bantime-increment.enable = true;
      ignoreIP = cfg.ignoreIP;
    };
  };
}
