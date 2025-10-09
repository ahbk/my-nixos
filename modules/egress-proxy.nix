# modules/egress-proxy.nix
{
  config,
  lib,
  pkgs,
  ids,
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
    users.users.egress-proxy = {
      isSystemUser = true;
      uid = ids.egress-proxy.uid;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keyFiles = [
        ../public-keys/service-egress-proxy-ssh-key.pub
      ];
      group = "egress-proxy";
    };

    users.groups.egress-proxy = {
      gid = ids.egress-proxy.uid;
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
