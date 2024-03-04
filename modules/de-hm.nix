ahbk: user: cfg: { config, pkgs, ... }: {
  programs.foot = {
    enable = true;
    settings = {
      main.font = "Source Code Pro:size=11";
      main.include = "~/.config/foot/include.ini";
      main.dpi-aware = "no";
      mouse.hide-when-typing = "yes";
      colors.alpha = .8;
    };
  };
  home.file.".config/foot/include.ini".source = ./foot.ini;

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile ./hypr.conf;
  };

  home.file.".config/hypr/wallpaper.jpg".source = ./hypr.jpg;

  home.packages = with pkgs; [
    fuzzel
    swaybg
    wl-clipboard
    signal-desktop
    qutebrowser firefox chromium
    mpv mupdf feh
  ];
}
