{
  lib,
  users,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  facter.reportPath = ./facter.json;

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager = {
      enable = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  my-nixos = {
    users = with users; {
      inherit admin alex;
    };

    sysadm.rescueMode = true;
    shell.alex.enable = true;
    hm.alex.enable = true;
    desktop-env.alex.enable = true;

    wireguard.wg0.enable = true;
    sendmail.alex.enable = true;
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
