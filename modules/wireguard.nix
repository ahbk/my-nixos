{ config
, host
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.wireguard;
  hosts = import ../hosts.nix;
in {

  options.ahbk.wireguard = with types; {
    enable = mkEnableOption (mdDoc "Configure this host to be part of 10.0.0.0/24");
    keepalive = mkOption {
      type = int;
      default = 25;
    };
    port = mkOption {
      type = port;
      default = 51820;
    };
    device = mkOption {
      type = str;
      default = "wg0";
    };
    ipForward = mkOption {
      type = bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {

    boot.kernel.sysctl."net.ipv4.ip_forward" = mkDefault (if cfg.ipForward then "1" else "0");

    networking = {
      wireguard.enable = true;
      networkmanager.unmanaged = [ "interface-name:${cfg.device}" ];
      interfaces.${cfg.device}.useDHCP = false;
    } // (if builtins.hasAttr "publicAddress" host then {
      firewall.allowedUDPPorts = [ cfg.port ];
    } else { });

    age.secrets."wg-key-${host.name}" = {
      file = ../secrets/wg-key-${host.name}.age;
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

          wireguardConfig = ({
            PrivateKeyFile = config.age.secrets."wg-key-${host.name}".path;
          } // (if builtins.hasAttr "publicAddress" host then {
            ListenPort = cfg.port;
          } else { }));

          wireguardPeers = mapAttrsToList (peerName: peerCfg: {
            wireguardPeerConfig = {
              PublicKey = peerCfg.wgKey;
              AllowedIPs = [ "${peerCfg.address}/32" ];
            } // (if builtins.hasAttr "publicAddress" peerCfg then {
              Endpoint = "${peerCfg.publicAddress}:${builtins.toString cfg.port}";
            } else {
              PersistentKeepalive = cfg.keepalive;
            });
          }) (filterAttrs (host: cfg: builtins.hasAttr "wgKey" cfg) hosts);
        };
      };

      networks.${cfg.device} = {
        matchConfig.Name = cfg.device;
        address = [ "${host.address}/24" ];
      };
    };

  };
}
