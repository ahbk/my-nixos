{ pkgs, ... }:
{
  my-nixos.sysadm.rescueMode = true;
  nixpkgs.hostPlatform = "x86_64-linux";
  networking = {
    useDHCP = true;
    networkmanager.enable = true;
  };
  environment.systemPackages = [ pkgs.nmtui ];
}
