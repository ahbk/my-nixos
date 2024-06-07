{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.my-nixos-hm.vd;
in
{
  options.my-nixos-hm.vd = {
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
