{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkOption
    mkIf
    types
    ;

  cfg = config.my-nixos.tls-certs;

in
{
  options.my-nixos.tls-certs = mkOption {
    type = types.listOf types.str;
    default = [ ];
    description = "List of self signed certificates to accept and expose";
  };

  config = mkIf (builtins.length cfg.tls-certs > 0) {
    security.pki.certificates = builtins.map (
      name: (builtins.readFile ../domains/${name}-tls-cert.pem)
    ) cfg.tls-certs;

    sops.secrets = builtins.listToAttrs (
      builtins.map (name: {
        name = "cert-${name}";
        value = {
          sopsFile = ../domains/users.yaml;
        };
      }) cfg.tls-certs
    );
  };
}
