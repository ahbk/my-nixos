{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    types
    mkEnableOption
    mkOption
    mkIf
    getExe
    ;
  cfg = config.my-nixos.glesys.updaterecord;
in
{

  options.my-nixos.glesys.updaterecord = with types; {
    enable = mkEnableOption "updating DNS-record on glesys";
    recordid = mkOption {
      description = "The glesys id of the record";
      type = str;
    };
    cloudaccount = mkOption {
      description = "Glesys account id.";
      type = str;
    };
    device = mkOption {
      description = "Device that should be watched.";
      example = "enp3s0";
      type = str;
    };
  };

  config = mkIf cfg.enable {

    age.secrets."api-key-glesys" = {
      file = ../secrets/api-key-glesys.age;
      owner = "root";
      group = "root";
    };

    systemd.services."glesys-updaterecord" = {
      description = "update A record for stationary.ahbk.se";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = let
        user = "${cfg.cloudaccount}:$(<${config.age.secrets."api-key-glesys".path})";
        data = "recordid=${cfg.recordid}&data=$ipv4";
        endpoint = "https://api.glesys.com/domain/updaterecord";
      in {
        ExecStart = pkgs.writeShellScript "glesys-updaterecord" ''
          ipv4="$(${pkgs.iproute2}/bin/ip -4 -o addr show ${cfg.device} | ${pkgs.gawk}/bin/awk '{split($4, a, "/"); print a[1]}')"
          ${getExe pkgs.curl} -sSX POST -d "${data}" -u ${user} ${endpoint} | ${pkgs.util-linux}/bin/logger -t dhcpcd
        '';
      };
    };

    systemd.timers."glesys-updaterecord" = {
      description = "update A record for stationary.ahbk.se every 10 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec="5min";
        OnUnitActiveSec="10min";
      };
    };
  };
}
