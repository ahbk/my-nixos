{
  networking = {
    firewall.enable = false;
    useDHCP = false;
    nameservers = [ "8.8.8.8" "8.8.4.4" ];
  };
  boot.isContainer = true;
}
