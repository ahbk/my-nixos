# modules/egress-proxy.nix
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.my-nixos.egress-proxy;
in
{
  options.my-nixos.egress-proxy = {
    enable = mkEnableOption "SOCKS proxy service";
  };

  config = mkIf (cfg.enable) {
    my-nixos.users.egress-proxy = {
      class = "service";
    };

    services.openssh.extraConfig = ''
      Match User egress-proxy
        AllowTcpForwarding local
        X11Forwarding no
        AllowAgentForwarding no
        PermitTunnel no
        PermitTTY no
    '';
  };
}
