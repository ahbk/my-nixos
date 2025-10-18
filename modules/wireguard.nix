# modules/wireguard.nix
{
  config,
  host,
  lib,
  lib',
  pkgs,
  org,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    ;

  cfg = config.my-nixos.wireguard;

  enabledSubnets = filterAttrs (iface: cfg: cfg.enable) org.subnet;

  isServer = hostCfg: lib.hasAttr "endpoint" hostCfg;

  peerAddress =
    subnet: peer: builtins.replaceStrings [ "x" ] [ (toString peer.id) ] subnet.peerAddress;

  createPeer =
    iface: subnet: peerName: peerCfg:
    let
      base = {
        PublicKey = builtins.readFile ../public-keys/host-${peerName}-${iface}-key.pub;
        AllowedIPs = [
          (if peerName == subnet.gateway then subnet.address else "${peerAddress subnet peerCfg}/32")
        ];
      };
      serverConfig = {
        Endpoint = "${peerCfg.endpoint}:${toString subnet.port}";
      };
      clientConfig = {
        PersistentKeepalive = subnet.keepalive;
      };
    in
    base // (if isServer peerCfg then serverConfig else clientConfig);

  peers =
    iface:
    filterAttrs (
      _: otherHost:
      lib.elem "peer" otherHost.roles
      && lib.elem iface otherHost.subnets
      && (isServer otherHost || isServer host)
    ) org.host;

  resetOnRebuilds =
    subnets:
    lib.mapAttrsToList (iface: cfg: "${pkgs.iproute2}/bin/ip link delete ${iface}") (
      lib.filterAttrs (iface: cfg: cfg.resetOnRebuild) enabledSubnets
    );
in
{
  options.my-nixos.wireguard.enable = lib.mkOption {
    description = "enable wireguard subnets on this host";
    type = lib.types.bool;
    default = lib.elem "peer" host.roles;
  };

  config = lib.mkIf (cfg.enable) {

    systemd.services."systemd-networkd".preStop = lib.concatStringsSep "\n" (
      resetOnRebuilds enabledSubnets
    );

    networking = {
      wireguard.enable = true;
      networkmanager.unmanaged = map (iface: "interface-name:${iface}") (lib.attrNames enabledSubnets);
      firewall.interfaces = lib.mapAttrs (_: subnet: {
        inherit (subnet) allowedTCPPortRanges;
      }) enabledSubnets;
      firewall.allowedUDPPorts = lib.optionals (isServer host) (
        lib.mapAttrsToList (iface: cfg: cfg.port) enabledSubnets
      );
      interfaces = lib.mapAttrs (_: _: { useDHCP = false; }) enabledSubnets;
    };

    sops.secrets = lib.mapAttrs' (
      iface: cfg:
      lib.nameValuePair "${iface}-key" {
        owner = "systemd-network";
        group = "systemd-network";
      }
    ) enabledSubnets;

    boot.kernel.sysctl."net.ipv4.ip_forward" = lib.elem host.name (
      mapAttrsToList (_: cfg: cfg.gateway) enabledSubnets
    );

    systemd.network = {
      enable = true;
      netdevs = lib.mapAttrs' (
        iface: cfg:
        lib.nameValuePair "10-${iface}" {
          netdevConfig = {
            Kind = "wireguard";
            Name = iface;
          };
          wireguardConfig = {
            PrivateKeyFile = config.sops.secrets."${iface}-key".path;
            ListenPort = if isServer host then cfg.port else null;
          };
          wireguardPeers = mapAttrsToList (createPeer iface cfg) (peers iface);
        }
      ) enabledSubnets;

      networks = lib'.mergeAttrs (iface: cfg: {
        "10-${iface}" = {
          matchConfig.Name = iface;
          address = [ "${peerAddress cfg host}/24" ];
          dns = map (dns: peerAddress cfg org.host.${dns}) cfg.dns;
        };

        "40-${iface}" = {
          matchConfig.Name = iface;
          networkConfig = {
            Description = "snapshot from nixos-facter hardware detection";
            DHCP = "no";
            IPv6PrivacyExtensions = "kernel";
          };
        };
      }) enabledSubnets;
    };
  };
}
