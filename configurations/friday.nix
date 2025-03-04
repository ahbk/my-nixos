{ pkgs, ... }:
let
  users = import ../users.nix;
in
{

  my-nixos = {
    users = with users; {
      inherit alex frans;
    };
    shell.frans.enable = true;

    shell.alex.enable = true;
    ide.alex.enable = true;
    hm.alex.enable = true;
    desktop-env.alex.enable = true;

    wireguard.wg0.enable = true;

  };

  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  environment.systemPackages = [ pkgs.mesa ];
  boot.initrd.kernelModules = [ "i915" ];
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

}
