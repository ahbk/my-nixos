{ user, ... }: {
  networking.hosts = {
    "127.0.0.2" = [ user ];
  };
  services.dnsmasq = {
    enable = true;
    settings.address = "/.${user}/127.0.0.2";
  };
}
