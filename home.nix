{ config, pkgs, ... }:

{
  home.username = "frans";
  home.homeDirectory = "/home/frans";
  home.enableNixpkgsReleaseCheck = true;
  home.shellAliases = {
    battery=''cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status'';
    brightness=''xrandr --output eDP-1 --brightness $1'';
    ll=''ls -lha'';
    hdmi=''xrandr --output HDMI-1 --auto --right-of eDP-1'';
  };

  programs.neovim = {
    enable = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
        nvim-tree-lua
	nvim-web-devicons
    ];
    extraLuaConfig = (builtins.readFile ./nvim-init.lua);
  };

  programs.bash = {
    enable = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  programs.foot = {
    enable = true;
    settings = {
      main.term = "xterm-256color";
      main.font = "Source Code Pro";
      main.dpi-aware = "yes";
      mouse.hide-when-typing = "yes";
    };
  };

  programs.git = {
    enable = true;
    userName = "Alexander Holmbäck";
    userEmail = "alexander.holmback@gmail.com";
  };

  home.packages = with pkgs; [ 
  ];

  home.stateVersion = "22.11";

  programs.home-manager.enable = true;
}
