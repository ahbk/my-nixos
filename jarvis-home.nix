{ config, pkgs, lib, ... }: {
  imports = [
    ./common-home.nix
  ];

  home.file.".config/hypr/hyprland.conf".source = ./hypr/hyprland-jarvis.conf;

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

