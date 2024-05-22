{ config
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.wgClient;
in {

  options.ahbk.wgClient = with types; {
    enable = mkEnableOption (mdDoc "Configure a wireguard client for this host");
    host = mkOption {
      type = str;
    };
    publicKey = mkOption {
      type = str;
    };
    address = mkOption {
      type = str;
    };
    endpoint = mkOption {
      type = str;
    };
    keepalive = mkOption {
      type = int;
    };
    allowedIPs = mkOption {
      type = listOf str;
    };
    device = mkOption {
      type = str;
      default = "wg0";
    };
  };

  config = mkIf cfg.enable {

    networking = {
      wireguard.enable = true;
      networkmanager.unmanaged = [ "interface-name:${cfg.device}" ];
    };

    age.secrets."wg-key-${cfg.host}" = {
      file = ../secrets/wg-key-${cfg.host}.age;
      owner = "systemd-network";
      group = "systemd-network";
    };

    systemd.network = {
      enable = true;
      netdevs = {
        "10-${cfg.device}" = {
          netdevConfig = {
            Kind = "wireguard";
            Name = cfg.device;
          };
          wireguardConfig = {
            PrivateKeyFile = config.age.secrets."wg-key-${cfg.host}".path;
          };
          wireguardPeers = [
            {
              wireguardPeerConfig = {
                PublicKey = cfg.publicKey;
                AllowedIPs = cfg.allowedIPs;
                Endpoint = cfg.endpoint;
                PersistentKeepalive = cfg.keepalive;
              };
            }
          ];
        };
      };
      networks.${cfg.device} = {
        matchConfig.Name = cfg.device;
        address = [ cfg.address ];
      };
    };

  };
}
