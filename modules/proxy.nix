{
  config,
  lib,
  pkgs,
  ids,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.my-nixos.proxy;
in
{
  options.my-nixos.proxy = {
    enable = mkEnableOption "SOCKS proxy service";
  };

  config = mkIf (cfg.enable) {
    users.users.proxy = {
      isSystemUser = true;
      uid = ids.proxy.uid;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keyFiles = [
        ../public-keys/service-proxy-ssh-key.pub
      ];
      group = "proxy";
    };

    users.groups.proxy = {
      gid = ids.proxy.uid;
    };

    services.openssh.extraConfig = ''
      Match User proxy
        AllowTcpForwarding local
        X11Forwarding no
        AllowAgentForwarding no
        PermitTunnel no
        PermitTTY no
    '';
  };
}
