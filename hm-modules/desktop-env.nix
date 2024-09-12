{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf getExe mkEnableOption;
  inherit (builtins) substring;
  inherit (import ../theme.nix) colors fonts;
  unhashedHexes = lib.mapAttrs (n: c: substring 1 6 c) colors;
  cfg = config.my-nixos-hm.desktop-env;
in

{
  options.my-nixos-hm.desktop-env = {
    enable = mkEnableOption "Desktop Environment for this user";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      chromium
      firefox
      feh
      kooha
      mpv
      mupdf
      pinta
      shotcut
      signal-desktop
      thunderbird
      wl-clipboard
    ];

    home.file.wallpaper = {
      source = ../wallpaper.jpg;
      target = ".config/hypr/wallpaper.jpg";
    };

    programs.foot = {
      enable = true;
      settings = {
        main.font = "${fonts.monospace}:size=11";
        main.dpi-aware = "no";
        mouse.hide-when-typing = "yes";
        colors = with unhashedHexes; {
          alpha = 0.8;
          background = base00;
          foreground = base07;

          regular0 = base00;
          regular1 = base01;
          regular2 = base02;
          regular3 = base03;
          regular4 = base04;
          regular5 = base05;
          regular6 = base06;
          regular7 = base07;

          bright0 = base08;
          bright1 = base09;
          bright2 = base0A;
          bright3 = base0B;
          bright4 = base0C;
          bright5 = base0D;
          bright6 = base0E;
          bright7 = base0F;
        };
      };
    };

    programs.qutebrowser = {
      enable = true;
      extraConfig = ''
        c.url.searchengines = {'DEFAULT': 'https://ecosia.org/search?q={}'}
        config.unbind('<Ctrl-W>')
        config.unbind('D')
        config.unbind('d')
        config.bind('h', 'history')
        config.bind('x', 'tab-close')
        config.bind('<Ctrl-O>', 'back')
        config.bind('<Ctrl-I>', 'forward')
      '';
      settings = with colors; {
        input = {
          links_included_in_focus_chain = false;
        };
        search = {
          incremental = false;
        };
        url = {
          start_pages = [ "qute://history/" ];
          default_page = "qute://history/";
        };
        content = {
          pdfjs = true;
          cache = {
            appcache = true;
            maximum_pages = 7;
          };
        };
        fonts = {
          default_family = [ fonts.monospace ];
          default_size = "11pt";
          hints = "default_size default_family";
        };
        hints.border = "1px solid ${bg-400}";
        colors = {
          completion = {
            category = {
              bg = bg-300;
              border.bottom = bg-300;
              border.top = bg-300;
              fg = fg-300;
            };
            even.bg = bg-400;
            fg = fg-400;
            item.selected = {
              bg = bg-selected;
              border.bottom = bg-selected;
              border.top = bg-selected;
              fg = fg-selected;
              match.fg = fg-match-selected;
            };
            match.fg = fg-match;
            odd.bg = bg-500;
            scrollbar.bg = bg-500;
            scrollbar.fg = fg-500;
          };
          contextmenu = {
            disabled.bg = bg-disabled;
            disabled.fg = fg-disabled;
            menu.bg = bg-400;
            menu.fg = fg-400;
            selected.bg = bg-selected;
            selected.fg = fg-selected;
          };
          downloads = {
            bar.bg = bg-400;
            error.bg = bg-error;
            error.fg = fg-error;
            start.bg = bg-400;
            start.fg = fg-400;
            stop.bg = bg-success;
            stop.fg = fg-success;
            system.bg = "rgb";
            system.fg = "rgb";
          };
          hints = {
            bg = bg-400;
            fg = fg-400;
            match.fg = fg-match;
          };
          keyhint = {
            bg = bg-400;
            fg = fg-400;
            suffix.fg = fg-match;
          };
          messages = {
            error.bg = bg-error;
            error.border = bg-error;
            error.fg = fg-error;
            info.bg = bg-info;
            info.border = bg-info;
            info.fg = fg-info;
            warning.bg = bg-warning;
            warning.border = bg-warning;
            warning.fg = fg-warning;
          };
          prompts = {
            bg = bg-400;
            border = bg-400;
            fg = fg-400;
            selected.bg = bg-selected;
            selected.fg = fg-selected;
          };
          statusbar = {
            caret.bg = bg-400;
            caret.fg = fg-400;
            caret.selection.bg = bg-400;
            caret.selection.fg = fg-400;
            command.bg = bg-400;
            command.fg = fg-400;
            command.private.bg = bg-400;
            command.private.fg = fg-400;
            insert.bg = bg-400;
            insert.fg = fg-400;
            normal.bg = bg-400;
            normal.fg = fg-400;
            passthrough.bg = bg-400;
            passthrough.fg = fg-400;
            private.bg = bg-400;
            private.fg = fg-400;
            progress.bg = bg-400;
            url.error.fg = fg-error;
            url.fg = fg-400;
            url.hover.fg = fg-400;
            url.success.http.fg = fg-success;
            url.success.https.fg = fg-success;
            url.warn.fg = fg-warning;
          };

          tabs = {
            bar.bg = bg-400;
            even.bg = bg-400;
            even.fg = fg-400;
            indicator = {
              error = bg-error;
              start = bg-info;
              stop = bg-success;
              system = "rgb";
            };
            odd.bg = bg-400;
            odd.fg = fg-400;
            pinned = {
              even.bg = bg-500;
              even.fg = fg-500;
              odd.bg = bg-500;
              odd.fg = fg-500;
              selected = {
                even.bg = bg-selected;
                even.fg = fg-selected;
                odd.bg = bg-selected;
                odd.fg = fg-selected;
              };
            };
            selected = {
              even.bg = bg-selected;
              even.fg = fg-selected;
              odd.bg = bg-selected;
              odd.fg = fg-selected;
            };
          };
          tooltip = {
            bg = bg-400;
            fg = fg-400;
          };
        };
      };
    };

    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          spacing = 4;
          output = [
            "eDP-1"
            "HDMI-A-1"
          ];
          modules-right = [ "battery" ];
          modules-center = [ "clock" ];
          clock = {
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            format-alt = "{:%A %Y-%m-%d}";
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              weeks-pos = "left";
              format = with colors; {
                months = "<span color='${green-400}'><b>{}</b></span>";
                days = "<span color='${white-400}'><b>{}</b></span>";
                weeks = "<span color='${purple-400}'><b>{}</b></span>";
                weekdays = "<span color='${yellow-400}'><b>{}</b></span>";
                today = "<span color='${red-400}'><b><u>{}</u></b></span>";
              };
            };
          };
        };
      };
      style = with colors; ''
        * {
          font-family: ${fonts.monospace};
          background-color: ${bg-400};
        }
        #battery {
          padding: 0 10px;
          border-radius: 10px;
          background-color: ${blue-400};
        }
        #clock {
          padding: 0 10px;
          background-color: ${bg-300};
          color: ${fg-300};
        }
      '';
    };

    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        monitor = ",preferred,auto,1";
        exec-once = [
          "${getExe pkgs.swaybg} -i ${config.home.file.wallpaper.target}"
          "${getExe pkgs.waybar}"
        ];

        general = {
          gaps_out = 10;
        };

        input = {
          kb_layout = "us,se";
          kb_options = "grp:alt_shift_toggle";
          repeat_rate = 35;
          repeat_delay = 175;
          follow_mouse = true;
          touchpad = {
            natural_scroll = true;
            tap-and-drag = true;
          };
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          disable_autoreload = true;
        };

        animations = {
          enabled = true;
          animation = [
            "global, 1, 5, default"
            "workspaces, 1, 1, default"
          ];
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        gestures = {
          workspace_swipe = true;
        };

        device = [
          {
            name = "epic-mouse-v1";
            sensitivity = -0.5;
          }
          {
            name = "wacom-intuos-pt-m-pen";
            transform = 0;
            output = "HDMI-A-1";
          }
        ];

        windowrule = [
          "float, ^(.*)$"
          "size 550 350, ^(.*)$"
          "center, ^(.*)$"
        ];
        "$mainMod" = "SUPER";

        bind =
          [
            "$mainMod, i, exec, ${lib.getExe pkgs.foot}"
            "$mainMod, o, exec, ${lib.getExe pkgs.qutebrowser}"
            "$mainMod, r, exec, ${lib.getExe pkgs.fuzzel}"
            ''$mainMod, p, exec, ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" - | ${lib.getExe pkgs.swappy} -f -''
            ", PRINT, exec, ${lib.getExe pkgs.grim} - | ${pkgs.wl-clipboard}/bin/wl-copy"
            "$mainMod, return, togglefloating,"
            "$mainMod, c, killactive,"
            "$mainMod, q, exit,"
            "$mainMod, d, pseudo,"
            "$mainMod, s, togglesplit,"
            "$mainMod, h, movefocus, l"
            "$mainMod, l, movefocus, r"
            "$mainMod, k, movefocus, u"
            "$mainMod, j, movefocus, d"
            "$mainMod, mouse_down, workspace, e+1"
            "$mainMod, mouse_up, workspace, e-1"
          ]
          ++ map (i: "$mainMod, ${toString i}, workspace, ${toString i}") [
            1
            2
            3
            4
            5
            6
            7
            8
            9
          ]
          ++ map (i: "$mainMod SHIFT, ${toString i}, movetoworkspacesilent, ${toString i}") [
            1
            2
            3
            4
            5
            6
            7
            8
            9
          ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };

  };
}
