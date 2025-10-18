# modules/reverse-tunnel.nix
{
  config,
  lib,
  lib',
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
    my-nixos.users.reverse-tunnel = {
      class = "service";
      passwd = true;
    };

    networking.firewall.allowedTCPPorts = [
      lib'.ids.reverse-tunnel.port
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
