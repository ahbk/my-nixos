{ config, users, ... }:
{
  imports = [
    ./disko.nix
  ];

  sops.secrets.luks-secret-key = { };
  boot = {
    initrd = {
      network.enable = false;
      secrets."/secret.key" = config.sops.secrets.luks-secret-key.path;
    };
    loader.grub.enable = true;
  };

  networking = {
    useDHCP = false;
    firewall = {
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
    users = with users; {
      inherit admin alex;
    };

    wireguard.wg0.enable = true;

    nginx = {
      enable = true;
      email = users.admin.email;
    };

    backup.km = {
      enable = true;
      target = "stationary.km";
    };

    mailserver = {
      enable = true;
      domain = "kompismoln.se";
      dkimSelector = "k1";

      users = {
        admin = { };
        alex = { };
      };

      domains = {
        "kompismoln.se".mailbox = true;
        "chatddx.com".mailbox = true;
        "sverigesval.org".mailbox = true;
        "esse.nu".mailbox = false;
        "klimatkalendern.nu".mailbox = false;
      };
    };
  };
}
