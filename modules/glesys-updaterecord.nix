{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.ahbk.glesys.updaterecord;
in {

  options.ahbk.glesys.updaterecord = with types; {
    enable = mkEnableOption (mdDoc "Update DNS-record on glesys");
    recordid = mkOption {
      type = str;
    };
    cloudaccount = mkOption {
      type = str;
    };
    device = mkOption {
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
