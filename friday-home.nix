{ config, pkgs, ... }: {
  imports = [
    ./common-home.nix
  ];

 wayland.windowManager.hyprland = {
   enable = true;
   extraConfig = builtins.readFile ./hypr/hyprland.conf;
 };

 programs.foot = {
   enable = true;
   settings = {
     main.term = "xterm-256color";
     main.font = "Source Code Pro:size=10";
     main.include = "~/Desktop/nixos/foot/theme.ini";
     main.dpi-aware = "yes";
     mouse.hide-when-typing = "yes";
     colors.alpha = .8;
   };
 };

}
