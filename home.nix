{ config, pkgs, ... }:

{
  home.username = "frans";
  home.homeDirectory = "/home/frans";
  home.enableNixpkgsReleaseCheck = true;

  programs.neovim = {
    enable = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
        nvim-tree-lua
	nvim-web-devicons
    ];
    extraLuaConfig = (builtins.readFile ./nvim-init.lua);
  };

  programs.zsh = {
    enable = true;
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
