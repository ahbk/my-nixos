ahbk: user: cfg: { config, pkgs, ... }: {
  programs.foot = {
    enable = true;
    settings = {
      main.font = "Source Code Pro:size=11";
      main.dpi-aware = "no";
      mouse.hide-when-typing = "yes";
      colors = {
        alpha = .8;
        foreground="dcdccc";
        background="111111";

        regular0="222222" ; # black
        regular1="cc9393";  # red
        regular2="7f9f7f";  # green
        regular3="d0bf8f";  # yellow
        regular4="6ca0a3";  # blue
        regular5="dc8cc3";  # magenta
        regular6="93e0e3";  # cyan
        regular7="dcdccc";  # white

        bright0="666666";   # bright black
        bright1="dca3a3";   # bright red
        bright2="bfebbf";   # bright green
        bright3="f0dfaf";   # bright yellow
        bright4="8cd0d3";   # bright blue
        bright5="fcace3";   # bright magenta
        bright6="b3ffff";   # bright cyan
        bright7="ffffff";   # bright white
      };
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = ",preferred,auto,1";
      exec-once = "${pkgs.swaybg} -i ${config.home.file.wallpaper.target}";
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
      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };
      decoration = {
        rounding = 10;
        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
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
        "$mainMod, i, exec, foot"
        "$mainMod, o, exec, qutebrowser"
        "$mainMod, return, togglefloating,"
        "$mainMod, c, killactive,"
        "$mainMod, q, exit,"
        "$mainMod, r, exec, ${pkgs.fuzzel}"
        "$mainMod, p, pseudo,"
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
    wl-clipboard
    signal-desktop
    thunderbird
    qutebrowser firefox chromium
    mpv mupdf feh
  ];
}
