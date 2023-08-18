{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware/friday.nix
    ./common.nix
  ];

  networking.hostName = "friday";

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
