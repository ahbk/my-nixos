{ pkgs, user, isHM, ... }:
let
  hm = {
    home.file.".config/nvim/lua/".source = ./nvim.lua;
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
      extraLuaConfig = (builtins.readFile ./nvim.lua);
    };

    home.packages = with pkgs; [ 
      fzf
      nil
      lua-language-server
      nodePackages.typescript-language-server
      nodePackages.typescript
      nodePackages.svelte-language-server
      pyright
    ];
  };
  nvim-window-picker = pkgs.vimUtils.buildVimPlugin {
    name = "nvim-window-picker";
    src = pkgs.fetchFromGitHub {
      owner = "s1n7ax";
      repo = "nvim-window-picker";
      rev = "41cfaa4";
      sha256 = "sha256-D5ikm5Fw0N/AjDL71cuATp1OCONuxPZNfEHuh0vXkq0=";
    };
  };
in if isHM then hm else {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };

  home-manager.users.${user} = hm;
}
