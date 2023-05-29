{ config, pkgs, ... }:
let
  nvim-window-picker = pkgs.vimUtils.buildVimPlugin {
    name = "nvim-window-picker";
    src = pkgs.fetchFromGitHub {
      owner = "s1n7ax";
      repo = "nvim-window-picker";
      rev = "5902827";
      sha256 = "sha256-1UbT/W1ngDnxX03aOk2V8VTOlXWyq/LjCfOl5MUOfsI=";
    };
  };
in {
  home.username = "frans";
  home.homeDirectory = "/home/frans";
  home.enableNixpkgsReleaseCheck = true;
  home.shellAliases = {
    battery = ''cat /sys/class/power_supply/BAT/capacity && cat /sys/class/power_supply/BAT/status'';
    nix-store-size = ''ls /nix/store | wc -l'';
    f = ''fzf --print0 | xargs -0 -o xdg-open'';
  };

  programs.neovim = {
    enable = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      (nvim-treesitter.withPlugins (p: [
                                    p.nix
                                    p.python
                                    p.svelte
                                    p.typescript
                                    p.html
                                    p.css p.scss
      ]))
      neo-tree-nvim nvim-web-devicons nvim-window-picker
      vim-sleuth vim-fugitive
      nvim-lspconfig fidget-nvim
      telescope-nvim leap-nvim mini-nvim
      vim-svelte
    ];
    extraLuaConfig = (builtins.readFile ./nvim/built-nvim.lua);
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    escapeTime = 10;
    mouse = true;
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
      main.font = "Source Code Pro:size=8";
      main.include = "~/Desktop/nixos/foot/theme.ini";
      main.dpi-aware = "yes";
      mouse.hide-when-typing = "yes";
      colors.alpha = .8;
    };
  };

  programs.git = {
    enable = true;
    userName = "Alexander Holmbäck";
    userEmail = "alexander.holmback@gmail.com";
  };

  home.packages = with pkgs; [ 
    ranger lazygit
  ];

  home.stateVersion = "22.11";

  programs.home-manager.enable = true;
}
