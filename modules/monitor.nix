{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.monitor;
in
{
  options.my-nixos.monitor = {
    enable = mkEnableOption "monitor service";
    config = mkOption {
      description = ''
        Configuration lines to add to /etc/monitrc.
      '';
      type = types.lines;
      default = '''';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.interfaces.wg0.allowedTCPPorts = [ 2812 ];

    services.monit = {
      inherit (cfg) enable config;
    };
  };
}
