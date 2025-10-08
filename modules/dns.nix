{
  lib,
  host,
  hosts,
  config,
  subnets,
  ...
}:
let
  cfg = config.my-nixos.dns;
  subnet = subnets.${cfg.subnet};
  listen = subnet.peerAddress host;
  hint = hostname: hostconf: "hints['${subnet.fqdn hostname}'] = '${subnet.peerAddress hostconf}'";
  hints = lib.mapAttrsToList hint hosts;
in
{
  options.my-nixos.dns = {
    enable = lib.mkEnableOption "dns hints on this host";
    subnet = lib.mkOption {
      type = lib.types.str;
      description = "Which subnet to act dns on";
    };
  };
  config = lib.mkIf (cfg.enable) {
    services.kresd = {
      enable = true;
      listenPlain = [ "${listen}:53" ];
      extraConfig = ''
        modules = { 'hints > iterate' }
        ${lib.concatStringsSep "\n" hints}
      '';
    };
  };
}
