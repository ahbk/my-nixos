ahbk: user: cfg: {
  config,
  pkgs,
  lib,
  theme,
  ...
}:

with theme.colors;
with theme.fonts;

let
  unhashedHexes = lib.mapAttrs (n: c: builtins.substring 1 6 c) theme.colors;
in {
  config = lib.mkIf cfg.enable {
    programs.foot = {
      enable = true;
      settings = {
        main.font = "${monospace}:size=11";
        main.dpi-aware = "no";
        mouse.hide-when-typing = "yes";
        colors = with unhashedHexes; {
          alpha = .8;
          background = base00;
          foreground = base0F;

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
      settings = {
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
          default_family = [ monospace ];
          default_size = "11pt";
          hints = "default_size default_family";
        };
        hints.border = "1px solid ${black-100}";
        colors = {
          statusbar = {
            normal.bg = black-100;
            normal.fg = white-600;
            insert.bg = black-100;
            insert.fg = white-600;
            passthrough.bg = blue-400;
            passthrough.fg = white-600;
          };
          completion = {
            fg = white-600;
            even.bg = black-100;
            odd.bg = black-400;
            match.fg = red-200;
            scrollbar.fg = white-600;
            scrollbar.bg = black-100;
            item = {
              selected.bg = white-600;
              selected.fg = black-100;
              selected.border.top = white-600;
              selected.border.bottom = white-600;
              selected.match.fg = red-200;
            };
            category = {
              bg = black-600;
              fg = white-400;
              border.bottom = black-300;
              border.top = black-300;
            };
          };
          tabs = {
            bar.bg = black-100;
            even.bg = black-100;
            even.fg = white-600;
            odd.bg = black-100;
            odd.fg = white-600;
            selected = {
              even.bg = white-600;
              even.fg = black-100;
              odd.bg = white-600;
              odd.fg = black-100;
            };
          };
          hints = {
            bg = black-100;
            fg = white-600;
            match.fg = red-500;
          };
        };
      };
    };

    programs.waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position  = "top";
          height = 30;
          spacing = 4;
          output = [
            "eDP-1"
            "HDMI-A-1"
          ];
          modules-right = [ "battery" ];
          modules-center = [ "clock" ];
          clock = {
            tooltip-format =  "<tt><small>{calendar}</small></tt>";
            format-alt = "{:%A %Y-%m-%d}";
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              weeks-pos = "left";
              format = {
                months = "<span color='${green-600}'><b>{}</b></span>";
                days = "<span color='${white-600}'><b>{}</b></span>";
                weeks = "<span color='${purple-400}'><b>{}</b></span>";
                weekdays = "<span color='${yellow-700}'><b>{}</b></span>";
                today = "<span color='${red-200}'><b><u>{}</u></b></span>";
              };
            };
          };
        };
      };
      style = ''
      * {
        font-family: ${monospace};
        background-color: ${black-100};
      }
      #battery {
        padding: 0 10px;
        border-radius: 10px;
        background-color: ${blue-400};
      }
      #clock {
        padding: 0 10px;
        background-color: ${black-400};
        color: ${white-600};
      }
      '';
    };

    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        monitor = ",preferred,auto,1";
        exec-once = [
          "${lib.getExe pkgs.swaybg} -i ${config.home.file.wallpaper.target}"
          "${lib.getExe pkgs.waybar}"
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
          { name = "epic-mouse-v1"; sensitivity = -0.5; }
          { name = "wacom-intuos-pt-m-pen"; transform = 0; output = "HDMI-A-1"; }
        ];

        windowrule = [
          "float, ^(.*)$"
          "size 550 350, ^(.*)$"
          "center, ^(.*)$"
        ];
        "$mainMod" = "SUPER";

        bind = [
          "$mainMod, i, exec, ${lib.getExe pkgs.foot}"
          "$mainMod, o, exec, ${lib.getExe pkgs.qutebrowser}"
          "$mainMod, r, exec, ${lib.getExe pkgs.fuzzel}"
          "$mainMod, p, exec, ${lib.getExe pkgs.grim} -g \"$(${lib.getExe pkgs.slurp})\" - | ${lib.getExe pkgs.swappy} -f -"
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
        ++ map (i: "$mainMod, ${toString i}, workspace, ${toString i}") [ 1 2 3 4 5 6 7 8 9 ]
        ++ map (i: "$mainMod SHIFT, ${toString i}, movetoworkspacesilent, ${toString i}") [ 1 2 3 4 5 6 7 8 9 ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };

    home.file.wallpaper = {
      source = ../wallpaper.jpg;
      target = ".config/hypr/wallpaper.jpg";
    };

    home.packages = with pkgs; [
      pinta
      wl-clipboard
      signal-desktop
      thunderbird
      firefox chromium
      mpv mupdf feh
    ];
  };
}
