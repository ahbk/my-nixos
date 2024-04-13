ahbk: user: cfg: { config, pkgs, lib, ... }: let
  base16 = import ./base16.nix;
in with base16; {
  programs.foot = {
    enable = true;
    settings = {
      main.font = "Source Code Pro:size=11";
      main.dpi-aware = "no";
      mouse.hide-when-typing = "yes";
      colors = {
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
                months = "<span color='#${base0A}'><b>{}</b></span>";
                days = "<span color='#${base0F}'><b>{}</b></span>";
                weeks = "<span color='#${base0D}'><b>{}</b></span>";
                weekdays = "<span color='#${base0B}'><b>{}</b></span>";
                today = "<span color='#${base01}'><b><u>{}</u></b></span>";
              };
            };
          };
        };
      };
    style = ''
      * {
        font-family: Source Code Pro;
        background-color: #${base00};
      }
      #battery {
        padding: 0 10px;
        border-radius: 10px;
        background-color: #${base06};
      }
      #clock {
        padding: 0 10px;
        background-color: #${base08};
        color: #${base0F};
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
    qutebrowser firefox chromium
    mpv mupdf feh
  ];
}
