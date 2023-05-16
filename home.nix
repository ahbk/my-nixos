{ config, pkgs, ... }:

{
  home.username = "frans";
  home.homeDirectory = "/home/frans";
  home.enableNixpkgsReleaseCheck = true;

  wayland.windowManager.sway = {
    enable = true;
    config = rec {
      modifier = "Mod4";
      terminal = "kitty"; 
    };
  };

  programs.git = {
    enable = true;
    userName = "Alexander Holmbäck";
    userEmail = "alexander.holmback@gmail.com";
  };

  home.packages = [ 
  ];

  programs.kitty = {
    enable = true;
  };

  home.stateVersion = "22.11";

  programs.home-manager.enable = true;
}
