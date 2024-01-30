{
  networking.firewall.enable = false;
  networking.useDHCP = false;
  services.nginx.enable = true;
  services.openssh.enable = true;
  boot.isContainer = true;
}
