{ config
, lib
, ...
}:

with lib;
with builtins;

let
  cfg = config.my-nixos.laptop;
in {
  options.my-nixos.laptop = with types; {
    enable = mkEnableOption "Enable power management on the host";
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
