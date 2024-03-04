ahbk: user: cfg: { config, pkgs, ... }: {
  home.file.".config/nvim/lua/".source = ./nvim.lua;
  home.packages = with pkgs; [ 
    xh
    mkcert
    (sqlite.override { interactive = true; })
    pyright
    nil
    lua-language-server
    nodePackages.svelte-language-server
    nodePackages.typescript-language-server
    nodejs
    node2nix
    hugo
    php
    gcc
  ];

  programs = {
    git = {
      enable = true;
      userName = ahbk.user.${user}.name;
      userEmail = ahbk.user.${user}.email;
    };

    neovim = {
      enable = true;
      vimAlias = true;
      vimdiffAlias = true;
      plugins = with pkgs.vimPlugins; [
        (nvim-treesitter.withPlugins (p: [
          p.c
          p.nix
          p.lua
          p.vimdoc
          p.python
          p.svelte
          p.typescript
          p.javascript
          p.html
          p.css p.scss
        ]))
        neo-tree-nvim
        nvim-web-devicons
        telescope-nvim
        telescope-fzf-native-nvim
        nvim-lspconfig
        luasnip
        nvim-cmp
        cmp_luasnip
        cmp-nvim-lsp
        vim-sleuth
        vim-fugitive
        leap-nvim
        mini-nvim
        toggleterm-nvim
        kanagawa-nvim
        vim-nix
      ];
      extraLuaConfig = (builtins.readFile ./nvim.lua);
    };
  };
}
