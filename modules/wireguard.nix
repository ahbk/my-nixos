# modules/wireguard.nix
{
  config,
  host,
  hosts,
  lib,
  lib',
  pkgs,
  subnets,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    ;

  enabledSubnets = filterAttrs (iface: cfg: cfg.enable) subnets;

  isServer = hostCfg: lib.hasAttr "endpoint" hostCfg;

  createPeer =
    iface: subnet: peerName: peerCfg:
    let
      base = {
        PublicKey = builtins.readFile ../public-keys/host-${peerName}-${iface}-key.pub;
        AllowedIPs = [
          (if peerName == subnet.gateway then subnet.address else "${subnet.peerAddress peerCfg}/32")
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
      _: otherHost: lib.elem iface otherHost.subnets && (isServer otherHost || isServer host)
    ) hosts;

  resetOnRebuilds =
    subnets:
    lib.mapAttrsToList (iface: cfg: "${pkgs.iproute2}/bin/ip link delete ${iface}") (
      lib.filterAttrs (iface: cfg: cfg.resetOnRebuild) enabledSubnets
    );
in
{

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
        address = [ "${cfg.peerAddress host}/24" ];
        dns = map (dns: cfg.peerAddress hosts.${dns}) cfg.dns;
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
}
