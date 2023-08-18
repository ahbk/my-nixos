{ config, pkgs, ... }: {
  imports = [
    ./common-home.nix
  ];

  home.file.".config/hypr/hyprland.conf".source = ./hypr/hyprland-friday.conf;

  programs.foot = {
    enable = true;
    settings = {
      main.term = "xterm-256color";
      main.font = "Source Code Pro:size=8";
      main.include = "~/Desktop/nixos/foot/theme.ini";
      main.dpi-aware = "yes";
      mouse.hide-when-typing = "yes";
      colors.alpha = .8;
    };
  };

}
