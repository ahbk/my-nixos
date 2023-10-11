{ inputs, pkgs, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
    ./inadyn/default.nix
  ];

  networking.hostName = "jarvis";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8000 80 443 ];
  };
  services.networking.inadyn = {
    enable = true;
    configFile = /home/frans/inadyn.conf;
  };

  services.openssh.enable = true;
  services.nginx = {
    enable = true;
    virtualHosts."ahbk.ddns.net" = {
      addSSL = true;
      enableACME = true;
      root = "/var/www/ahbk.ddns.net";
    };
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "alxhbk@proton.me";
  };
  environment.systemPackages = with pkgs; [
    iotop
    hdparm
  ];
}
