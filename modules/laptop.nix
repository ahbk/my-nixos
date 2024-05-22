{ config
, lib
, ...
}:

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
  };
}
