{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.my-nixos-hm.vd;
in
{
  options.my-nixos-hm.vd = {
    enable = mkEnableOption "Enable visual design tools for this user";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      inkscape
      figma-linux
      krita
    ];
  };
}
