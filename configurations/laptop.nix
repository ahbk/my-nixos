let
  hosts = import ../hosts.nix;
  users = import ../users.nix;
in {
  my-nixos = {
    user = with users; { inherit alex frans backup; };
    shell.frans.enable = true;
    ide.frans = {
      enable = true;
      postgresql = true;
      mysql = true;
      userAsTopDomain = false;
    };
    hm.frans.enable = true;
    de.frans.enable = true;
    vd.frans.enable = true;

    laptop.enable = true;

    wireguard.wg0.enable = true;

    mailClient."alex" = {
      enable = true;
    };

    backup.stationary = {
      enable = true;
      repository = "sftp:backup@${hosts.stationary.address}:repository";
    };
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "wlp1s0";
    };
    networkmanager.unmanaged = [ "interface-name:ve-*" ];
    firewall.allowedTCPPorts = [ 3000 5173 8000 ];
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

  services.dnsmasq = {
    enable = false;
    settings.address = "/.test/10.233.1.2";
  };

  # Purism librem 13v2 has unusual keycode for pipe/backslash
  # https://forums.puri.sm/t/keyboard-layout-unable-to-recognize-pipe/2022
  systemd.services.pipefix = {
    wantedBy = [ "multi-user.target" ];
    after = [ "nix-daemon.socket" ];
    before = [ "systemd-user-sessions.service" ];
    script = ''/run/current-system/sw/bin/setkeycodes 56 43'';
  };
}
