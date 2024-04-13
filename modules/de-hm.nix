ahbk: user: cfg: { config, pkgs, ... }: let
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

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = ",preferred,auto,1";
      exec-once = "${pkgs.swaybg}/bin/swaybg -i ${config.home.file.wallpaper.target}";

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
        "$mainMod, i, exec, foot"
        "$mainMod, o, exec, qutebrowser"
        "$mainMod, r, exec, fuzzel"
        "$mainMod, return, togglefloating,"
        "$mainMod, c, killactive,"
        "$mainMod, q, exit,"
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
    fuzzel
    wl-clipboard
    signal-desktop
    thunderbird
    qutebrowser firefox chromium
    mpv mupdf feh
  ];
}
