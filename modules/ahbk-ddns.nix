{
  imports = [
    ./inadyn.nix
  ];

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
