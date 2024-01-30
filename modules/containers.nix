{
  # give container access to host network
  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "wlp1s0";
    };
    networkmanager.unmanaged = [ "interface-name:ve-*" ];
  };

  services.dnsmasq = {
    enable = true;
    settings.address = "/.test/10.233.2.2";
  };
}
