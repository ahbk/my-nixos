{ config, ...}: {
  age.secrets."rolf_secret_key" = {
    file = ./secrets/rolf_secret_key.age;
    owner = "rolf";
    group = "rolf";
  };

  age.secrets."chatddx_secret_key" = {
    file = ./secrets/chatddx_secret_key.age;
    owner = "chatddx.com";
    group = "chatddx.com";
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
    host = "chatddx.com";
    port = "8001";
    uid = 994;
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

  services.networking.inadyn = {
    enable = true;
    providers."default@noip.com" = {
      username = "alexander.holmback@gmail.com";
      hostname = "ahbk.ddns.net";
      passwordFile = config.age.secrets."ddns-password".path;
    };
  };

}
