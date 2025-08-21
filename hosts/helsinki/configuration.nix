{
  config,
  users,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  sops.secrets.luks-key = { };
  boot = {
    loader.grub.enable = true;
    initrd = {
      systemd.enable = true;
      secrets."/luks-key" = config.sops.secrets.luks-key.path;
    };
  };

  boot.initrd.systemd.services."format-root" = {
    enable = true;
    description = "Format the root LV partition at boot";
    unitConfig = {
      DefaultDependencies = "no";
      Requires = "dev-pool-root.device";
      After = "dev-pool-root.device";
      Before = "sysroot.mount";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.e2fsprogs}/bin/mkfs.ext4 -F /dev/pool/root";
    };
    wantedBy = [ "initrd.target" ];
  };

  networking = {
    useDHCP = false;
    firewall = {
      logRefusedConnections = false;
    };
  };

  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
  fileSystems."/srv/storage".neededForBoot = true;
  preservation = {
    enable = true;
    preserveAt."/srv/storage" = {
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd"
      ];
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
        {
          file = "/etc/ssh/ssh_host_ed25519_key";
          mode = "0600";
          inInitrd = true;
        }
        {
          file = "/etc/ssh/ssh_host_ed25519_key-";
          mode = "0600";
          inInitrd = true;
        }
      ];
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

  security.sudo.extraRules = [
    {
      users = [
        "admin"
      ];
      runAs = "root";
      commands = [
        {
          command = "/run/current-system/sw/bin/cryptsetup open --test-passphrase *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  my-nixos = {
    sysadm.rescueMode = true;
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
