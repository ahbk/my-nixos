{
  lib',
  ...
}:
{
  boot = {
    loader.grub.enable = true;
  };

  networking = {
    useDHCP = false;
    dhcpcd.enable = false;
    useNetworkd = true;
    firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
      logRefusedConnections = false;
    };
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        Address = [
          "65.108.214.112/32"
          "2a01:4f9:c012:e514::/64"
        ];
        Gateway = [
          "172.31.1.1"
          "fe80::1"
        ];
        DNS = [
          "185.12.64.1"
          "185.12.64.2"
        ];
      };
      routes = [
        {
          Destination = "172.31.1.1/32";
          Scope = "link";
        }
        {
          Destination = "0.0.0.0/0";
          Gateway = "172.31.1.1";
          GatewayOnLink = "yes";
        }
      ];
    };
  };

  my-nixos = {
    sysadm.rescueMode = true;

    dns-hints = {
      enable = true;
      subnet = "wg0";
    };

    nginx = {
      enable = true;
      monitor = true;
    };

    svelte.sites."chatddx" = rec {
      enable = true;
      appname = "chatddx";
      hostname = "chatddx.com";
      ssl = true;
      api = "${if ssl then "https" else "http"}://${hostname}";
      api_ssr = "http://localhost:${toString lib'.ids."${appname}-django".port}";
    };

    django.sites."chatddx" = {
      enable = true;
      appname = "chatddx";
      hostname = "chatddx.com";
      packagename = "chatddx_backend";
      celery.enable = true;
      locationProxy = "/admin";
    };

    wordpress.sites."esse" = {
      enable = true;
      appname = "esse";
      hostname = "esse.nu";
      www = "yes";
    };

    mobilizon.sites."klimatkalendern" = {
      enable = true;
      hostname = "klimatkalendern.nu";
      appname = "klimatkalendern";
      www = "redirect";
      port = lib'.ids.klimatkalendern.port;
      uid = lib'.ids.klimatkalendern.uid;
    };

    nextcloud.sites."nextcloud-kompismoln" = {
      enable = true;
      hostname = "nextcloud.kompismoln.se";
      uid = lib'.ids.nextcloud-kompismoln.uid;
      port = lib'.ids.nextcloud-kompismoln.port;
      collaboraHost = "collabora.kompismoln.se";
      mounts = { };
    };

    collabora = {
      enable = true;
      host = "collabora.kompismoln.se";
      allowedHosts = [ ];
    };

    nextcloud-rolf.sites."sverigesval-sync" = {
      enable = true;
      hostname = "sverigesval.org";
      username = "nextcloud-kompismoln";
      www = "redirect";
      siteRoot = "/var/lib/nextcloud-kompismoln/nextcloud/data/rolf/files/+pub/_site";
      sourceRoot = "/var/lib/nextcloud-kompismoln/nextcloud/data/rolf/files/+pub";
    };
  };

  services.nginx.virtualHosts."nc.kompismoln.se" = {
    forceSSL = true;
    enableACME = true;
    locations."/".return = "301 https://nextcloud.kompismoln.se$request_uri";
  };

  services.nginx.virtualHosts."admin.sverigesval.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/".return = "301 https://nextcloud.kompismoln.se$request_uri";
  };

}
