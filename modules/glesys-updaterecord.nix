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

    networking.dhcpcd.runHook =
      let
        user = "${cfg.cloudaccount}:$(<${config.age.secrets."api-key-glesys".path})";
        data = "recordid=${cfg.recordid}&data=$new_ip_address";
        endpoint = "https://api.glesys.com/domain/updaterecord";
      in
      ''
        if [ "$interface" = "${cfg.device}" ] && [ -n "$new_ip_address" ]; then
          ${getExe pkgs.curl} -X POST -d "${data}" -u ${user} ${endpoint} | ${pkgs.util-linux}/bin/logger -t dhcpcd
        fi
      '';
  };
}
