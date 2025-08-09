{
  config,
  host,
  lib,
  ...
}:

let
  inherit (lib)
    filterAttrs
    hasAttr
    mapAttrsToList
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.my-nixos.wireguard;
  hosts = import ../hosts.nix;
  isGateway = cfg: cfg.name == "stationary";
  isServer = cfg: hasAttr "publicAddress" cfg;
  isPeer = cfg: hasAttr "wgKey" cfg;
in
{

  options.my-nixos.wireguard.wg0 = with types; {
    enable = mkEnableOption "this host to be part of 10.0.0.0/24";
    keepalive = mkOption {
      description = "Keepalive interval.";
      type = int;
      default = 25;
    };
    port = mkOption {
      description = "Listening port for establishing a connection.";
      type = port;
      default = 51820;
    };
  };

  config = mkMerge [
    (mkIf cfg.wg0.enable {
      services.prometheus = {
        exporters.wireguard.enable = true;
        scrapeConfigs = with config.services.prometheus.exporters; [
          {
            job_name = "wireguard";
            static_configs = [
              {
                targets = [
                  "glesys.ahbk:${toString wireguard.port}"
                  "stationary.ahbk:${toString wireguard.port}"
                  "laptop.ahbk:${toString wireguard.port}"
                ];
              }
            ];
          }
        ];
      };

      networking = {
        wireguard.enable = true;
        networkmanager.unmanaged = [ "interface-name:wg0" ];
        firewall = {
          interfaces.wg0 = {
            allowedTCPPortRanges = [
              {
                from = 0;
                to = 65535;
              }
            ];
          };
        }
        // (optionalAttrs (isServer host) { allowedUDPPorts = [ cfg.wg0.port ]; });
        interfaces.wg0 = {
          useDHCP = false;
        };
      };

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

            wireguardConfig = (
              {
                PrivateKeyFile = config.age.secrets."wg-key-${host.name}".path;
              }
              // (if isServer host then { ListenPort = cfg.wg0.port; } else { })
            );

            wireguardPeers = mapAttrsToList (
              peerName: peerCfg:
              {
                PublicKey = peerCfg.wgKey;
                AllowedIPs = [ (if isGateway peerCfg then "10.0.0.0/24" else "${peerCfg.address}/32") ];
              }
              // (
                if isServer peerCfg then
                  { Endpoint = "${peerCfg.publicAddress}:${toString cfg.wg0.port}"; }
                else
                  { PersistentKeepalive = cfg.wg0.keepalive; }
              )
            ) (filterAttrs (_: cfg: (isPeer cfg) && ((isServer cfg) || (isServer host))) hosts);
          };
        };

        networks."10-wg0" = {
          matchConfig.Name = "wg0";
          address = [ "${host.address}/24" ];
          dns = [ "10.0.0.1" ];
        };
      };
    })
  ];
}
