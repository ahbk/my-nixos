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
        description = "Install and run inadyn as a service";
        relatedPackages = [ "inadyn" ];
      };

      configFile = mkOption {
        type = types.path;
        default = "/etc/inadyn.conf";
        example = "/home/user/inadyn.conf";
        description = "Location of config file";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.inadyn ];

    systemd.services.inadyn = {
      documentation = [
        "man:inadyn"
        "man:inadyn.conf"
        "file:${pkgs.inadyn}/share/doc/inadyn/README.md"
      ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        ConditionPathExists=cfg.configFile;
        ExecStart = pkgs.inadyn + "/bin/inadyn --foreground --syslog --config ${cfg.configFile}";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
