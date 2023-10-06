{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
  ];

  networking.hostName = "jarvis";
  services.openssh.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8000 ];
  };

}
