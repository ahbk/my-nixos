{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware/jarvis.nix
    ./common.nix
  ];

  networking.hostName = "jarvis";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8000 80 443 ];
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
    inadyn
  ];

  systemd.services.inadyn = {
    enable = true;
    description = "manage inadyn";
    unitConfig = {
      Type = "simple";
      After = [ "network-online.target" ];
      Requires = [ "network-online.target" ];
    };
    serviceConfig = {
      ExecStart = "${pkgs.inadyn}/bin/inadyn --foreground";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
