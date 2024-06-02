{ config
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.wg-server;
in {

  options.ahbk.wg-server = with types; {
    enable = mkEnableOption (mdDoc "Configure a wireguard client for this host");
    host = mkOption {
      type = str;
    };
    peers = mkOption {
      type = attrsOf attrs;
    };
    port = mkOption {
      type = port;
      default = 51820;
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

    age.secrets."wg-key-${cfg.host}" = {
      file = ../secrets/wg-key-${cfg.host}.age;
      owner = "systemd-network";
      group = "systemd-network";
    };

    boot.kernel.sysctl."net.ipv4.ip_forward" = "1";
    networking.firewall.allowedUDPPorts = [ cfg.port ];

    networking.wireguard = {
      enable = true;
      interfaces.${cfg.device} = {
        ips = [ cfg.address ];
        listenPort = cfg.port;
        privateKeyFile = config.age.secrets."wg-key-${cfg.host}".path;
        peers = mapAttrsToList (host: peerCfg: {
          name = peerCfg.name;
          publicKey = peerCfg.wgKey;
          persistentKeepalive = 25;
          allowedIPs = [ "${peerCfg.address}/32" ];
        } // (if builtins.hasAttr "publicAddress" peerCfg then {
          endpoint = "${peerCfg.publicAddress}:${builtins.toString cfg.port}";
        } else {
        })) cfg.peers;
      };
    };
  };
}
