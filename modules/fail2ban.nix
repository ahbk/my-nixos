{
  config,
  lib,
  org,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.my-nixos.fail2ban;
in
{
  options.my-nixos.fail2ban = {
    enable = mkEnableOption "the jails configured with `services.fail2ban.jails`";
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      maxretry = 1;
      bantime = "1d";
      bantime-increment.enable = true;
      ignoreIP = lib.mapAttrsToList (subnet: subnetCfg: subnetCfg.address) org.subnet;
    };
  };
}
