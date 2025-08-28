{
  config,
  lib,
  users,
  ...
}:
{
  facter.reportPath = ./facter.json;
  imports = [
    ./disko.nix
  ];

  sops.secrets.luks-key = { };
  boot = {
    initrd = {
      secrets."/luks-key" = config.sops.secrets.luks-key.path;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  sops.secrets.wifi-keys = {
    mode = "644";
    owner = "ami";
  };
  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager = {
      enable = true;
    };
  };

  services.xserver.enable = true;
  services.xserver.displayManager.lightdm = {
    enable = true;
  };
  services.xserver.desktopManager.cinnamon.enable = true;
  programs.firefox.enable = true;

  my-nixos = {
    sysadm.rescueMode = true;
    preserve = {
      enable = true;
      directories = [
        "/home"
        "/etc/NetworkManager"
      ];
    };

    users = with users; {
      inherit admin ami;
    };

    shell.admin.enable = true;
    shell.ami.enable = true;

    hm.ami.enable = true;
    wireguard.wg0.enable = true;
  };
}
