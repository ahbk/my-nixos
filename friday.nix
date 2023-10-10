{ inputs, pkgs, ... }: {
  imports = [
    ./hardware/friday.nix
    ./common.nix
  ];

  networking.hostName = "friday";

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  # pet projects
  networking.extraHosts = ''
      127.0.0.2 weblog.local
    '';

  # hw quirk: wrong keycode for pipe |
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
  };


}
