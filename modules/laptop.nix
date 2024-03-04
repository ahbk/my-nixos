{ config, lib, ... }:
with lib;
with builtins;
let
  cfg = config.ahbk.laptop;
in {
  options.ahbk.laptop = with types; {
    enable = mkOption {
      type = bool;
      default = false;
    };
  };
  config = mkIf cfg.enable {
    programs.light = {
      enable = true;
      brightnessKeys.step = 10;
      brightnessKeys.enable = true;
    };

    powerManagement.enable = true;
    services.thermald.enable = true;
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 40;

       START_CHARGE_THRESH_BAT0 = 50;
       STOP_CHARGE_THRESH_BAT0 = 90;
     };
   };
 };
}
