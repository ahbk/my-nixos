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
    enable = mkEnableOption "respond to phone home from stranded clients";
  };

  config = mkIf (cfg.enable) {
    sops.secrets."tunnelservice/passwd-hashed" = {
      neededForUsers = true;
      sopsFile = ../users/tunnelservice-enc.yaml;
    };

    users.users.tunnelservice = {
      isSystemUser = true;
      shell = pkgs.shadow;
      hashedPasswordFile = config.sops.secrets."tunnelservice/passwd-hashed".path;
      openssh.authorizedKeys.keyFiles = [
        ../users/tunnelservice-ssh-key.pub
      ];
      uid = ids.tunnelservice.uid;
      group = "tunnelservice";
    };

    users.groups.tunnelservice = {
      gid = ids.tunnelservice.uid;
    };

    networking.firewall.allowedTCPPorts = [
      ids.tunnelservice.port
    ];

    services.openssh = {
      enable = true;
      settings = {
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
