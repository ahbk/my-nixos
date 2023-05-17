{ config, pkgs, ... }:

{
  home.username = "frans";
  home.homeDirectory = "/home/frans";
  home.enableNixpkgsReleaseCheck = true;

  programs.neovim = {
    enable = true;
  };

  programs.zsh = {
    enable = true;
  };

  programs.git = {
    enable = true;
    userName = "Alexander Holmbäck";
    userEmail = "alexander.holmback@gmail.com";
  };

  home.packages = [ 
  ];

  #programs.foot = {
  #  enable = true;
  #  #server.enable = true;
  #  settings = {
  #  };
  #};

  home.stateVersion = "22.11";

  programs.home-manager.enable = true;
}
