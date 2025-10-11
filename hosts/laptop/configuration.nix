{
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  #facter.reportPath = ./facter.json;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking = {
    networkmanager = {
      enable = true;
    };
  };

  my-nixos = {
    sysadm.rescueMode = true;
  };

  # Purism librem 13v2 has unusual keycode for pipe/backslash
  # https://forums.puri.sm/t/keyboard-layout-unable-to-recognize-pipe/2022
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = "/run/current-system/sw/bin/setkeycodes 56 43";
  };
}
