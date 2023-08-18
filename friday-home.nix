{ config, pkgs, ... }: {
  imports = [
    ./common-home.nix
  ];

  home.file.".config/hypr/hyprland.conf".source = ./hypr/hyperland-friday.conf;
}
