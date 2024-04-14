ahbk: user: cfg: {
  config,
  pkgs,
  inputs,
  lib,
  theme,
  ...
}:
with theme.colors;
with theme.fonts;
{
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
          transparent = true;
          colors.palette = {
            sumiInk0 = black-100; # bg_m3 float.bf float.fg_border float.bg_border term:black
            sumiInk1 = black-200; # bg_dim bg_m2
            sumiInk2 = black-300; # bg_m1
            sumiInk3 = black-400; # bg
            sumiInk4 = black-500; # bg_gutter bg_p1
            sumiInk5 = black-600; # bg_p2
            sumiInk6 = black-700; # nontext whitespace
            fujiGray = black-800; # syn.comment term:bright black
            katanaGray = black-900; # deprecated

            winterBlue = blue-100; # diff.change
            waveBlue1 = blue-200; # fg_reverse bg_visual pmenu.bg pmenu.bg_sbar
            waveBlue2 = blue-300; # bg_search pmenu.bg_sel pmenu.bg_thumb
            crystalBlue = blue-400; # syn.fun term:blue
            springBlue = blue-500; # syn.special1 term:bright blue
            dragonBlue = blue-600; # diag.info
            lightBlue = blue-700; # syn.preproc?

            winterGreen = green-200; # diff.add
            autumnGreen = green-400; # vcs.added term:green
            springGreen = green-600; # syn.string diag.ok term:bright green

            winterYellow = yellow-200; # diff.text
            roninYellow = yellow-400; # diag.warning
            autumnYellow = yellow-500; # vcs.changed
            boatYellow1 = yellow-300;
            boatYellow2 = yellow-600; # syn.operator syn.regex term:yellow
            carpYellow = yellow-700; # syn.identifier term:bright yellow
            surimiOrange = yellow-800; # syn.constant term:ext1

            winterRed = red-100; # diff.delete
            autumnRed = red-200; # vcs.removed term:red
            samuraiRed = red-500; # diag.error term:bright red
            sakuraPink = red-300; # syn.number
            waveRed = red-400; # syn.preproc syn.special2
            peachRed = red-600; # syn.special3 term:ext2

            oniViolet = purple-300; # syn.statement syn.keyword term:magenta
            oniViolet2 = purple-700; # syn.parameter
            springViolet1 = purple-400; # special term: bright magenta
            springViolet2 = purple-500; # syn.punct
            
            waveAqua1 = cyan-300; # diag.hint term:cyan
            waveAqua2 = cyan-500; # syn.type term:bright cyan

            oldWhite = white-400; # fg_dim float.fg term:white
            fujiWhite = white-600; # fg pmenu.fg term:bright white
          };
        };
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
