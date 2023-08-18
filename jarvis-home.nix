{ config, pkgs, lib, ... }: {
  imports = [
    ./common-home.nix
  ];

  home.file.".config/hypr/hyprland.conf".source = ./hypr/hyprland-jarvis.conf;

  programs.foot.settings.main = lib.mkAfter {
    font = lib.mkForce "Source Code Pro:size=10";
    dpi-aware = lib.mkForce "no";
  };
}

