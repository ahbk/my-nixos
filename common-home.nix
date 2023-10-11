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
  programs.bash.bashrcExtra = ''export PATH="$PATH:$HOME/.local/bin"'';
  home.shellAliases = {
    nix-store-size = ''ls /nix/store | wc -l'';
    f = ''find | fzf --print0 | xargs -0 -o vim'';
    ls = ''ls --color=auto'';
    l = ''ls -la'';
    ll = ''ls'';
    grep = ''grep --color=auto'';
    seagull = ''sudo systemd-nspawn -b -D /home/frans/Desktop/seagull'';
    blackbird = ''sudo systemd-nspawn -b -D /var/lib/machines/blackbird'';
  };

  home.file.".config/nvim/lua/".source = ./nvim;
  home.file.".config/hypr/wallpaper.jpg".source = ./hypr/wallpaper.jpg;

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
      neo-tree-nvim
      nvim-web-devicons
      nvim-window-picker
      vim-sleuth
      vim-fugitive
      nvim-lspconfig
      telescope-nvim
      telescope-fzf-native-nvim
      leap-nvim
      mini-nvim
      vim-svelte
      vim-nix
      luasnip
      nvim-cmp
      cmp_luasnip
      cmp-nvim-lsp
      nvim-lspconfig
      toggleterm-nvim
      everforest
      gruvbox
      kanagawa-nvim
    ];
    extraLuaConfig = (builtins.readFile ./nvim/built-nvim.lua);
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-direct";
    keyMode = "vi";
    escapeTime = 10;
    extraConfig = (builtins.readFile ./tmux/tmux.conf);
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

  programs.git = {
    enable = true;
    userName = "Alexander Holmbäck";
    userEmail = "alexander.holmback@gmail.com";
  };

  programs.ssh = {
    enable = true;
  };

  home.packages = with pkgs; [ 
    ranger
    lazygit
    nil
    lua-language-server
    silver-searcher
    ripgrep
    fd
    fzf
    pyright
    black
    nodejs
    nodePackages.typescript-language-server
    nodePackages.typescript
    nodePackages.svelte-language-server
    hugo
    xh
  ];

  home.stateVersion = "22.11";

  programs.home-manager.enable = true;
}
