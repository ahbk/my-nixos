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

    age.secrets."${cfg.host}-wg" = {
      file = ../secrets/${cfg.host}-wg.age;
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
            PrivateKeyFile = config.age.secrets."laptop-wg".path;
          };
          wireguardPeers = [
            {
              wireguardPeerConfig = {
                PublicKey = cfg.publicKey;
                AllowedIPs = [ "10.0.0.0/24" ];
                Endpoint = "ahbk.ddns.net:51820";
                PersistentKeepalive = 25;
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
