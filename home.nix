{ config, pkgs, ... }:

{
  home.username = "frans";
  home.homeDirectory = "/home/frans";
  home.enableNixpkgsReleaseCheck = true;
  home.shellAliases = {
    battery=''cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status'';
  };

  programs.neovim = {
    enable = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      (nvim-treesitter.withPlugins (p: [ p.nix ]))
      nvim-tree-lua nvim-web-devicons
      vim-sleuth
      nvim-lspconfig fidget-nvim
      telescope-nvim leap-nvim
    ];
    extraLuaConfig = (builtins.readFile ./nvim/built-nvim.lua);
  };

  programs.tmux = with pkgs.tmuxPlugins; {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    escapeTime = 10;
    mouse = true;
    plugins = [
      gruvbox
    ];
    extraConfig = (builtins.readFile ./tmux/buildpatch.conf);
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
