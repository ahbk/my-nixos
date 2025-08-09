{
  config,
  host,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    hasAttr
    mapAttrsToList
    mkEnableOption
    mkIf
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

  config = (mkIf cfg.wg0.enable) {
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

    systemd.services."systemd-networkd".preStop = ''
      # Force wireguard to restart when systemd-networkd restarts
      # (old keys remain otherwise)
      ${pkgs.iproute2}/bin/ip link delete wg0 || true
    '';

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

    sops.secrets.wg-key = {
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
              PrivateKeyFile = config.sops.secrets.wg-key.path;
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

      networks."40-wg0" = {
        matchConfig.Name = "wg0";
        networkConfig = {
          Description = "snapshot from nixos-facter hardware detection";
          # DHCP = "no";
          # IPv6PrivacyExtensions = "kernel";
        };
      };
    };
  };
}
