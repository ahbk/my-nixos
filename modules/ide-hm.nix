ahbk: user: cfg: { config, pkgs, inputs, lib, ... }: let
  base16 = lib.mapAttrs (n: v: "#" + v) (import ./base16.nix);
in {
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
  ];
  home.packages = with pkgs; [ 
    xh
    mkcert
    (sqlite.override { interactive = true; })
    pyright
    nil
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

    nixvim = {
      enable = true;
      vimAlias = true;
      colorschemes.kanagawa = {
        enable = true;
        settings = {
          transparent = false;
        };
      };
      colorschemes.base16 = {
        enable = false;
        colorscheme = "kanagawa";
      };
      opts = {
        number = true;
        shiftwidth = 2;
        wildmenu = true;
        wildmode = "longest:full,full";
      };
      keymaps = [
        { key = "<F2>"; action = "<cmd>Neotree toggle<cr>"; }
        { key = "<space>e"; action = "vim.diagnostic.open_float"; lua = true; }
      ];

      plugins = {
        leap.enable = true;
        sleuth.enable = true;
        neo-tree.enable = true;
        oil.enable = true;
        nix.enable = true;
        nvim-colorizer.enable = true;
        fugitive.enable = true;

        treesitter = {
          enable = true;
          indent = true;
        };

        telescope = {
          enable = true;
          keymaps = {
            "<leader>ff" = "find_files";
            "<leader>fg" = "live_grep";
          };
        };

        lsp = {
          enable = true;
          servers = {
            tsserver.enable = true;
            svelte.enable = true;
            pyright.enable = true;
            nil_ls.enable = true;
          };
        };

        cmp = {
          enable = true;
          autoEnableSources = true;
          settings = {
            sources = [
              { name = "nvim_lsp"; }
              { name = "luasnip"; }
              { name = "path"; }
              { name = "buffer"; }
            ];
            mapping = {
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-e>" = "cmp.mapping.close()";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            };
          };
        };

      };

    };
  };
}
