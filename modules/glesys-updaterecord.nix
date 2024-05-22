{ config
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.glesys.updaterecord;
in {

  options.ahbk.glesys.updaterecord = with types; {
    enable = mkEnableOption (mdDoc "Update DNS-record on glesys");
    recordid = mkOption {
      type = int;
    };
    cloudaccount = mkOption {
      type = str;
    };
    device = mkOption {
      type = str;
    };
  };

  config = mkIf cfg.enable {

    age.secrets."glesys-api-key" = {
      file = ../secrets/glesys-api-key.age;
      owner = "root";
      group = "root";
    };

    networking.dhcpcd.runHook = ''
    if [ "$interface" = ${cfg.device} ] && [ -n "$new_ip_address" ]; then
    echo "$interface got new address: $new_ip_address"
    ${getExe pkgs.curl} \
    -X POST \
    -d recordid=${toString cfg.recordid} \
    -d data=$new_ip_address \
    -k \
    --basic \
    -u ${cfg.cloudaccount}:$(<${config.age.secrets."glesys-api-key".path}) \
    https://api.glesys.com/domain/updaterecord
    fi
    '';

  };
}
