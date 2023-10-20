{ config, pkgs, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
    ./inadyn/default.nix
  ];

  ahbk.enable = true;

  age.secrets."ddns-password".file = ./secrets/ddns-password.age;

  networking.hostName = "jarvis";

  services.networking.inadyn = {
    enable = true;
    period = 300;
    providers."default@noip.com" = {
      username = "alexander.holmback@gmail.com";
      hostname = "ahbk.ddns.net";
      passwordFile = config.age.secrets."ddns-password".path;
    };
  };

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    iotop
    hdparm
  ];
}
