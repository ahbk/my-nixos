{ pkgs, ... }:
let
  users = import ../users.nix;
in
{

  my-nixos = {
    users = with users; {
      inherit alex johanna;
    };
    shell.alex.enable = true;

    wireguard.wg0.enable = true;

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
