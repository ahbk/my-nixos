{
  config,
  lib,
  ids,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  cfg = config.my-nixos.backup-server;
in
{
  options.my-nixos.backup-server = {
    enable = mkEnableOption ''a restic rest server on this host'';
    port = mkOption {
      type = types.port;
      default = ids.restic.port;
    };
  };
  config = mkIf (cfg.enable) {

    services.restic.server = {
      enable = true;
      prometheus = true;
      listenAddress = toString cfg.km.port;
      extraFlags = [ "--no-auth" ];
    };
  };
}
