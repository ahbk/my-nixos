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

  options.ahbk.wireguard.wg0 = with types; {
    enable = mkEnableOption (mdDoc "Configure this host to be part of 10.0.0.0/24");
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
      } // (if builtins.hasAttr "publicAddress" host then {
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
            } // (if builtins.hasAttr "publicAddress" host then {
              ListenPort = cfg.wg0.port;
            } else { }));

            wireguardPeers = mapAttrsToList (peerName: peerCfg: {
              wireguardPeerConfig = {
                PublicKey = peerCfg.wgKey;
                AllowedIPs = [ "${peerCfg.address}/32" ];
              } // (if builtins.hasAttr "publicAddress" peerCfg then {
                Endpoint = "${peerCfg.publicAddress}:${builtins.toString cfg.wg0.port}";
              } else {
                PersistentKeepalive = cfg.wg0.keepalive;
              });
            }) (filterAttrs (host: cfg: builtins.hasAttr "wgKey" cfg) hosts);
          };
        };

        networks.wg0 = {
          matchConfig.Name = "wg0";
          address = [ "${host.address}/24" ];
        };
      };

    })
  ];
}