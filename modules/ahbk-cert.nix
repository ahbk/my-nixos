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

    age.secrets = {
      ahbk-cert = {
        file = ../secrets/ahbk-cert.age;
        owner = "root";
        group = "root";
        mode = "644";
      };
      ahbk-cert-key = {
        file = ../secrets/ahbk-cert-key.age;
        owner = "root";
        group = "root";
        mode = "644";
      };
    };
  };
}
