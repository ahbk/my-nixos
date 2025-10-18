{ pkgs, ... }:
{

  imports = [
    ./hardware-configuration.nix
  ];

  my-nixos = {
    nix.facter = false;
    users = {
      johanna = {
        class = "user";
      };
      admin = {
        class = "user";
        groups = [ "wheel" ];
      };
    };
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  environment.systemPackages = with pkgs; [
    mesa
    librewolf
  ];
  networking.networkmanager.enable = true;
  boot.initrd.kernelModules = [ "i915" ];
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

}
