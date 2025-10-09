# modules/reverse-tunnel.nix
{
  config,
  lib,
  ids,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkForce
    ;
  cfg = config.my-nixos.reverse-tunnel;
in
{
  options.my-nixos.reverse-tunnel = {
    enable = mkEnableOption "respond to phone home from stranded clients";
  };

  config = mkIf (cfg.enable) {
    sops.secrets."reverse-tunnel/passwd-sha512" = {
      neededForUsers = true;
      sopsFile = ../enc/service-reverse-tunnel.yaml;
    };

    users.users.reverse-tunnel = {
      isSystemUser = true;
      shell = pkgs.shadow;
      hashedPasswordFile = config.sops.secrets."reverse-tunnel/passwd-sha512".path;
      openssh.authorizedKeys.keyFiles = [
        ../public-keys/service-reverse-tunnel-ssh-key.pub
      ];
      uid = ids.reverse-tunnel.uid;
      group = "reverse-tunnel";
    };

    users.groups.reverse-tunnel = {
      gid = ids.reverse-tunnel.uid;
    };

    networking.firewall.allowedTCPPorts = [
      ids.reverse-tunnel.port
    ];

    services.openssh = {
      enable = true;
      settings = {
        GatewayPorts = mkForce "clientspecified";
      };

      extraConfig = ''
        Match User reverse-tunnel
          ForceCommand /bin/false
          AllowTcpForwarding remote
          X11Forwarding no
          AllowAgentForwarding no
          PermitTunnel no
      '';
    };
  };
}
