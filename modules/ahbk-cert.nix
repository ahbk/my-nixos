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
    enable = mkEnableOption "desktop environment for this user";
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
