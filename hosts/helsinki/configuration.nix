{
  config,
  users,
  hosts,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
  ];
  facter.reportPath = ./facter.json;

  sops.secrets.luks-key = { };
  boot = {
    loader.grub.enable = true;
    initrd = {
      secrets."/luks-key" = config.sops.secrets.luks-key.path;
    };
  };

  services.kresd =
    let
      generateHints =
        hosts:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: host: "hints['${host.name}.km'] = '${host.address}'") hosts
        );
    in
    {
      enable = true;
      listenPlain = [ "10.0.0.5:53" ];
      extraConfig = ''
        modules = { 'hints > iterate' }
        ${generateHints hosts}
      '';
    };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking = {
    useDHCP = false;
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
    keyservice = {
      enable = true;
      luksDevice = "/dev/sda3";
    };
    tunnelservice.enable = true;

    preserve.enable = true;

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
