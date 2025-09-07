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

  tls-certs = config.my-nixos.tls-certs;

in
{
  options.my-nixos.tls-certs = mkOption {
    type = types.listOf types.str;
    default = [ ];
    description = "List of self signed certificates to accept and expose";
  };

  config = mkIf (tls-certs == [ ]) {
    security.pki.certificates = builtins.map (
      name: (builtins.readFile ../public-keys/domain-${name}-tls-cert.pem)
    ) tls-certs;

    sops.secrets = builtins.listToAttrs (
      builtins.map (name: {
        name = "cert-${name}";
        value = {
          sopsFile = ../enc/domain-km.yaml;
        };
      }) tls-certs
    );
  };
}
