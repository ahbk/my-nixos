{
  modulesPath,
  lib,
  config,
  users,
  ...
}:
{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "dwc3_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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
}
