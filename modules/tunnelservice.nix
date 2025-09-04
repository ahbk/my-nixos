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
  cfg = config.my-nixos.tunnelservice;
in
{
  options.my-nixos.tunnelservice = {
    enable = mkEnableOption "user tunnelservice";
  };

  config = mkIf (cfg.enable) {
    users.users.tunnelservice = {
      isSystemUser = true;
      shell = pkgs.shadow;

      openssh.authorizedKeys.keyFiles = [
        ../users/tunnelservice-ssh-key.pub
      ];
      uid = ids.tunnelservice.uid;
      group = "tunnelservice";
    };

    users.groups.tunnelservice = {
      gid = ids.tunnelservice.uid;
    };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        GatewayPorts = mkForce "clientspecified";
      };

      extraConfig = ''
        Match User tunnelservice
        ForceCommand /bin/false
        AllowTcpForwarding remote
        X11Forwarding no
        AllowAgentForwarding no
        PermitTunnel no
      '';
    };
  };
}
