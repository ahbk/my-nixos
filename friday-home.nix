{ config, pkgs, ... }: {
  imports = [
    ./common-home.nix
  ];

  home.file.".config/hypr/hyprland.conf".source = ./hypr/hyprland-friday.conf;
}
