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

  config = mkIf (tls-certs != [ ]) {
    security.pki.certificates = builtins.map (
      name: (builtins.readFile ../public-keys/service-domain-${name}-tls-cert.pem)
    ) tls-certs;

    users.groups.tls-cert = {
      members = [
        "nginx"
        #"zitadel"
      ];
    };

    sops.secrets = builtins.listToAttrs (
      builtins.map (name: {
        name = "domain-${name}/tls-cert";
        value = {
          sopsFile = ../enc/service-domain-${name}.yaml;
          owner = "root";
          group = "tls-cert";
          mode = "0440";
        };
      }) tls-certs
    );
  };
}
