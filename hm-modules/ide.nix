{
  config,
  lib,
  pkgs,
  ...
}:

let
  theme = import ../theme.nix;
  inherit (lib)
    types
    mkIf
    mkEnableOption
    mkOption
    ;
  inherit (theme) colors;
  cfg = config.my-nixos-hm.ide;
in

{

  options.my-nixos-hm.ide = with types; {
    enable = mkEnableOption "IDE for this user";
    name = mkOption {
      description = "Name for git.";
      type = str;
    };
    email = mkOption {
      description = "Email for git.";
      type = str;
    };
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      gcc
      hugo
      mkcert
      nil
      nixfmt-rfc-style
      node2nix
      nodejs
      nodePackages.svelte-language-server
      nodePackages.typescript-language-server
      npm-check-updates
      php
      pyright
      (sqlite.override { interactive = true; })
      xh
    ];

    programs = {
      git = {
        enable = true;
        userName = cfg.name;
        userEmail = cfg.email;
      };

      nixvim = {
        enable = true;
        vimAlias = true;
        colorschemes.kanagawa = {
          enable = true;
          settings = {
            transparent = false;
            colors.palette = with colors; {
              katanaGray = black-100; # deprecated
              fujiGray = black-200; # syn.comment term:bright black
              sumiInk6 = black-300; # nontext whitespace
              sumiInk5 = black-400; # bg_p2
              sumiInk4 = black-500; # bg_gutter bg_p1
              sumiInk3 = black-600; # bg
              sumiInk2 = black-700; # bg_m1
              sumiInk1 = black-800; # bg_dim bg_m2
              sumiInk0 = black-900; # bg_m3 float.bf float.fg_border float.bg_border term:black

              peachRed = red-300; # syn.special3 term:ext2
              autumnRed = red-400; # vcs.removed term:red
              samuraiRed = red-500; # diag.error term:bright red

              sakuraPink = pink-300; # syn.number
              waveRed = pink-400; # syn.preproc syn.special2
              winterRed = pink-500; # diff.delete

              springGreen = green-300; # syn.string diag.ok term:bright green
              autumnGreen = green-400; # vcs.added term:green
              winterGreen = green-500; # diff.add

              carpYellow = yellow-300; # syn.identifier term:bright yellow
              autumnYellow = yellow-400; # vcs.changed
              roninYellow = yellow-500; # diag.warning

              winterYellow = beige-500; # diff.text
              boatYellow1 = beige-400;
              boatYellow2 = beige-300; # syn.operator syn.regex term:yellow

              surimiOrange = orange-400; # syn.constant term:ext1

              lightBlue = blue-200; # syn.preproc?
              springBlue = blue-300; # syn.special1 term:bright blue
              crystalBlue = blue-400; # syn.fun term:blue
              waveBlue2 = blue-500; # bg_search pmenu.bg_sel pmenu.bg_thumb
              waveBlue1 = blue-600; # fg_reverse bg_visual pmenu.bg pmenu.bg_sbar
              winterBlue = blue-700; # diff.change

              oniViolet2 = purple-200; # syn.parameter
              springViolet1 = purple-300; # special term: bright magenta
              springViolet2 = purple-400; # syn.punct
              oniViolet = purple-500; # syn.statement syn.keyword term:magenta

              waveAqua2 = cyan-300; # syn.type term:bright cyan
              waveAqua1 = cyan-400; # diag.hint term:cyan
              dragonBlue = cyan-500; # diag.info

              oldWhite = white-500; # fg_dim float.fg term:white
              fujiWhite = white-400; # fg pmenu.fg term:bright white
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
          {
            key = "<F2>";
            action = "<cmd>Neotree toggle<cr>";
          }
          {
            key = "<space>e";
            action.__raw = "vim.diagnostic.open_float";
          }
          {
            key = "<leader>sh";
            action = ":split<cr>";
          }
          {
            key = "<leader>sv";
            action = ":vsplit<cr>";
          }
          {
            key = "<leader>c";
            action = ''"+yy'';
            mode = [ "n" ];
          }
          {
            key = "<leader>c";
            action = ''"+y'';
            mode = [ "v" ];
          }
        ];

        plugins = {
          leap.enable = true;
          sleuth.enable = true;
          neo-tree.enable = true;
          oil.enable = true;
          nix.enable = true;
          nvim-colorizer.enable = true;
          fugitive.enable = true;
          gitignore.enable = false;

          treesitter = {
            enable = true;
            indent = true;
          };

          telescope = {
            enable = true;
            keymaps = {
              "<leader>ff" = "find_files";
              "<leader>fg" = "live_grep";
              "<leader>fb" = "buffers";
            };
          };

          lsp = {
            enable = true;
            servers = {
              tsserver.enable = true;
              svelte.enable = true;
              pyright.enable = true;
              nil-ls.enable = true;
            };
            keymaps = {
              lspBuf = {
                K = "hover";
                gD = "references";
                gd = "definition";
                gi = "implementation";
                gt = "type_definition";
              };
              diagnostic = {
                "<leader>j" = "goto_next";
                "<leader>k" = "goto_prev";
              };
            };
          };

          cmp = {
            enable = true;
            autoEnableSources = true;
            settings = {
              completion = {
                keyword_length = 2;
              };
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
  };
}
