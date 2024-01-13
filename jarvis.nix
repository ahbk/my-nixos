{ config, pkgs, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
    ./inadyn/default.nix
  ];

  age.secrets."rolf_secret_key" = {
    file = ./secrets/rolf_secret_key.age;
    owner = "rolf";
    group = "rolf";
  };

  age.secrets."chatddx_secret_key" = {
    file = ./secrets/chatddx_secret_key.age;
    owner = "chatddx";
    group = "chatddx";
  };

  rolf = {
    enable = true;
    user = "rolf";
    www_root = "/var/www/sverigesval.org";
    hostname = "sverigesval.org";
    secret_key_file = config.age.secrets."rolf_secret_key".path;
  };

  chatddx = {
    enable = true;
    user = "chatddx";
    www_root = "/var/www/chatddx.com";
    db_root = "/var/db/chatddx.com";
    hostname = "chatddx.com";
    secret_key_file = config.age.secrets."chatddx_secret_key".path;
  };

  wordpress = {
    enable = true;
    host = "test.esse.nu";
    ssl = true;
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    security.acme = {
      acceptTerms = true;
      defaults.email = "alxhbk@proton.me";
    };
  };

  services.nginx.virtualHosts."_" = {
    default = true;
    locations."/" = {
      return = "444";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "alxhbk@proton.me";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

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
