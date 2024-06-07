{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my-nixos.glesys.updaterecord;
in {

  options.my-nixos.glesys.updaterecord = with types; {
    enable = mkEnableOption "DNS-record on glesys";
    recordid = mkOption {
      description = "The glesys id of the record";
      type = str;
    };
    cloudaccount = mkOption {
      description = "The glesys account id";
      type = str;
    };
    device = mkOption {
      description = "The device that should be watched.";
      type = str;
    };
  };

  config = mkIf cfg.enable {

    age.secrets."api-key-glesys" = {
      file = ../secrets/api-key-glesys.age;
      owner = "root";
      group = "root";
    };

    networking.dhcpcd.runHook = let
      user = "${cfg.cloudaccount}:$(<${config.age.secrets."api-key-glesys".path})";
      data = "recordid=${cfg.recordid}&data=$new_ip_address";
      endpoint = "https://api.glesys.com/domain/updaterecord";
    in ''
      if [ "$interface" = "${cfg.device}" ] && [ -n "$new_ip_address" ]; then
        ${getExe pkgs.curl} -X POST -d "${data}" -u ${user} ${endpoint} | ${pkgs.util-linux}/bin/logger -t dhcpcd
      fi
      '';

  };
}
