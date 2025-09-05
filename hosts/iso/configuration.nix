{
  my-nixos.sysadm.rescueMode = true;
  nixpkgs.hostPlatform = "x86_64-linux";
  networking = {
    networkmanager.enable = true;
  };
}
