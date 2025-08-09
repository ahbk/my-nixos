{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.my-nixos.ahbk-cert;

in
{
  options.my-nixos.ahbk-cert = {
    enable = mkEnableOption "make self-signed certificates available for ssl on local subnet";
  };

  config = mkIf (cfg.enable) {
    security.pki.certificates = [
      (builtins.readFile ../secrets/ahbk-cert.pem)
    ];

    sops.secrets.ahbk-cert-key = {
      mode = "644";
    };
  };
}
