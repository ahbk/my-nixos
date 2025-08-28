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

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager = {
      enable = true;
    };
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  programs.light.brightnessKeys.enable = true;

  my-nixos = {
    sysadm.rescueMode = true;
    users = with users; {
      inherit admin ami;
    };
    shell.admin.enable = true;

    shell.ami.enable = true;
    ide.ami = {
      enable = true;
      postgresql = true;
      redis = true;
    };
    hm.ami.enable = true;
    desktop-env.ami.enable = true;

    wireguard.wg0.enable = true;
  };
}
