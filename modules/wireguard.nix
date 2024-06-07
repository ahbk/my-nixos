{ config
, host
, lib
, ...
}:

with lib;
with builtins;

let
  cfg = config.my-nixos.wireguard;
  hosts = import ../hosts.nix;
  isGateway = cfg: cfg.name == "stationary";
  isServer = cfg: hasAttr "publicAddress" cfg;
  isPeer = cfg: hasAttr "wgKey" cfg;
in {

  options.my-nixos.wireguard.wg0 = with types; {
    enable = mkEnableOption "this host to be part of 10.0.0.0/24";
    keepalive = mkOption {
      type = int;
      default = 25;
    };
    port = mkOption {
      type = port;
      default = 51820;
    };
  };

  config = mkMerge [
    (mkIf cfg.wg0.enable {

      networking = {
        wireguard.enable = true;
        networkmanager.unmanaged = [ "interface-name:wg0" ];
        interfaces.wg0.useDHCP = false;
      } // (if isServer host then {
        firewall.allowedUDPPorts = [ cfg.wg0.port ];
      } else { });

      age.secrets."wg-key-${host.name}" = {
        file = ../secrets/wg-key-${host.name}.age;
        owner = "systemd-network";
        group = "systemd-network";
      };


      systemd.network = {
        enable = true;
        netdevs = {

          "10-wg0" = {
            netdevConfig = {
              Kind = "wireguard";
              Name = "wg0";
            };

            wireguardConfig = ({
              PrivateKeyFile = config.age.secrets."wg-key-${host.name}".path;
            } // (if isServer host then {
              ListenPort = cfg.wg0.port;
            } else { }));

            wireguardPeers = mapAttrsToList (peerName: peerCfg: {
              PublicKey = peerCfg.wgKey;
              AllowedIPs = [
                (if isGateway peerCfg then "10.0.0.0/24" else "${peerCfg.address}/32")
              ];
            } // (if isServer peerCfg then {
              Endpoint = "${peerCfg.publicAddress}:${toString cfg.wg0.port}";
            } else {
              PersistentKeepalive = cfg.wg0.keepalive;
            })) (filterAttrs (_: cfg: (isPeer cfg) && ((isServer cfg) || (isServer host))) hosts);
          };
        };

        networks.wg0 = {
          matchConfig.Name = "wg0";
          address = [ "${host.address}/24" ];
          dns = [ "10.0.0.1" ];
        };
      };

    })
  ];
}
