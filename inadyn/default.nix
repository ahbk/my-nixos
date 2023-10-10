{ config, pkgs, lib, ...}:
let
  inherit (lib) mkOption types mkIf;
  cfg = config.services.networking.inadyn;
in {
  options = {
    services.networking.inadyn = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc "Enable {command}`inadyn`";
        relatedPackages = [ "inadyn" ];
      };

      configFile = mkOption {
        type = types.path;
        default = "/etc/inadyn.conf";
        example = "/home/user/inadyn.conf";
        description = lib.mdDoc "Location of config file";
      };
    };
  };

  config = mkIf cfg.enable {
    environment = {
      #etc."inadyn.conf".text = inadynConf;
      systemPackages = [ pkgs.inadyn ];
    };

    systemd.services.inadyn = {
      enable = true;
      description = "manage inadyn";
      unitConfig = {
        Type = "simple";
        After = [ "network-online.target" ];
        Requires = [ "network-online.target" ];
      };
      serviceConfig = {
        ExecStart = "${pkgs.inadyn}/bin/inadyn --foreground --config ${cfg.configFile}";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
