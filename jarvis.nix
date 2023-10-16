{ inputs, pkgs, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
    ./inadyn/default.nix
  ];

  ahbk.enable = true;

  networking.hostName = "jarvis";

  services.networking.inadyn = {
    enable = true;
    configFile = /home/frans/inadyn.conf;
  };

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    iotop
    hdparm
  ];
}
