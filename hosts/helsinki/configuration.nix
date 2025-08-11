{ config, host, ... }:
let
  users = import ../../users.nix;
in
{
  imports = [
    ./disko.nix
  ];

  boot = {
    initrd = {
      network.enable = false;
      secrets."/secret.key" = config.sops.secrets.luks-secret-key.path;
    };
    loader.grub.enable = true;
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

  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets.luks-secret-key = { };

  networking = {
    useDHCP = false;
    firewall = {
      logRefusedConnections = false;
    };
  };

  my-nixos = {
    wireguard.wg0.enable = true;
    sysadm.rescueMode = true;
    users = with users; {
      inherit admin alex;
    };
  };

  system.stateVersion = "25.05";
}
