{ config, ... }:
let
  users = import ../users.nix;
in
{
  imports = [
    ./helsinki-disko.nix
  ];

  boot = {
    initrd.network.enable = false;
    loader.grub.enable = true;
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        Address = "65.108.214.112/32";
        Gateway = "172.31.1.1";
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
  boot.initrd.secrets."/secret.key" = config.sops.secrets.luks-secret-key.path;

  boot.initrd.luks.devices."crypted" = {
    # device = "/dev/disk/by-partlabel/disk-main-luks";
    # keyFile = "/secret.key";
  };

  sops.secrets.luks-secret-key = {
    sopsFile = ../secrets/luks.yaml;
  };

  networking = {
    useDHCP = false;
    firewall = {
      logRefusedConnections = false;
    };
  };

  #sops = {
  #  age = {
  #    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  #    keyFile = "/var/lib/sops-nix/key.txt";
  #    generateKey = true;
  #  };
  #};

  my-nixos = {
    rescue.enable = true;
    users = with users; {
      inherit admin alex;
    };
  };

  system.stateVersion = "25.05";
}
