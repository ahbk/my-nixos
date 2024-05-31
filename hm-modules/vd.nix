{ config
, pkgs
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk-hm.vd;
in {
  options.ahbk-hm.vd = {
    enable = mkEnableOption (mkDoc "Enable visual design tools for this user");
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      inkscape
      figma-linux
      krita
    ];
  };
}
