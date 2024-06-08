let
  users = import ../users.nix;
in
{
  my-nixos = {
    user = with users; {
      inherit alex frans backup;
    };
    shell.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = true;
      mysql = true;
    };
    hm.frans.enable = true;
    desktop-env.frans.enable = true;
    vd.frans.enable = true;

    wireguard.wg0.enable = true;

    mailClient."alex".enable = true;

    backup."backup.ahbk".enable = true;
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "wlp1s0";
    };
    networkmanager.unmanaged = [ "interface-name:ve-*" ];
    firewall.allowedTCPPorts = [
      3000
      5173
      8000
    ];
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  # Purism librem 13v2 has unusual keycode for pipe/backslash
  # https://forums.puri.sm/t/keyboard-layout-unable-to-recognize-pipe/2022
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = "/run/current-system/sw/bin/setkeycodes 56 43";
  };

  programs.light = {
    enable = true;
    brightnessKeys.step = 10;
    brightnessKeys.enable = true;
  };

  powerManagement.enable = true;

  services.thermald.enable = true;
}
