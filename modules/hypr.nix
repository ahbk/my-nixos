{ pkgs, user, ... }: {
  programs.hyprland.enable = true;
  home-manager.users.${user} = {
    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = builtins.readFile ./hypr.conf;
    };

    home.file.".config/hypr/wallpaper.jpg".source = ./hypr.jpg;

    home.packages = with pkgs; [
      fuzzel
      swaybg
      wl-clipboard
    ];
  };
}
