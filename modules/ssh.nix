{
  config,
  hosts,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkEnableOption
    mkIf
    ;
  cfg = config.my-nixos.ssh;
in
{
  options.my-nixos.ssh = {
    enable = mkEnableOption "ssh server";
  };

  config = mkIf (cfg.enable) {

    #programs.ssh.knownHosts = mapAttrs (host: cfg: {
    #  hostNames = [
    #    "${host}.kompismoln.se"
    #    "${host}.km"
    #    cfg.address
    #  ];
    #  publicKeyFile = ../public-keys/host-${host}-ssh-key.pub;
    #}) hosts;

    services.openssh.hostKeys = [
      {
        path = "/keys/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
