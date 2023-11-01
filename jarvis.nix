{ config, pkgs, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
    ./inadyn/default.nix
  ];

  rolf = {
    enable = true;
    user = "rolf";
    www_root = "/var/www/ahbk.ddns.net";
    hostname = "ahbk.ddns.net";

  };

  age.secrets."ddns-password".file = ./secrets/ddns-password.age;

  networking.hostName = "jarvis";

  services.networking.inadyn = {
    enable = true;
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
