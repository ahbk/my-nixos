# modules/index.nix
{
  inputs,
  host,
  lib,
  ...
}:
let
  roles = rec {
    base = [
      ../hosts/${host.name}/configuration.nix
      ./locksmith.nix
      ./nix.nix
      ./preserve.nix
      ./system.nix
    ];

    peer = [
      {
        my-nixos.tls-certs = [ "km" ];
      }
      ./backup.nix
      ./backup-server.nix
      ./fail2ban.nix
      ./sendmail.nix
      ./sops.nix
      ./ssh.nix
      ./tls-certs.nix
      ./users.nix
      ./wireguard.nix
    ]
    ++ base;

    workstation = [
      {
        nixpkgs.overlays = [
          (import ../overlays/workstation.nix { inherit inputs; })
        ];
      }
      ./desktop-env.nix
      ./hm.nix
      ./ide.nix
      ./mysql.nix
      ./postgresql.nix
      ./shell.nix
      ./vd.nix
    ]
    ++ peer;

    webserver = [
      {
        nixpkgs.overlays = [
          (import ../overlays/webserver.nix { inherit inputs; })
        ];
      }
      ./collabora.nix
      ./dns-hints.nix
      ./django-react.nix
      ./django.nix
      ./egress-proxy.nix
      ./fastapi-svelte.nix
      ./fastapi.nix
      ./mobilizon.nix
      ./monitor.nix
      ./mysql.nix
      ./nextcloud.nix
      ./nextcloud-rolf.nix
      ./nginx.nix
      ./postgresql.nix
      ./react.nix
      ./redis.nix
      ./reverse-tunnel.nix
      ./svelte.nix
      ./tls-certs.nix
      ./wordpress.nix
    ]
    ++ peer;

    mailserver = [
      ./mailserver.nix
    ]
    ++ peer;
  };
in
{
  imports = lib.optionals (lib.hasAttr "roles" host) lib.concatMap (role: roles.${role}) host.roles;
}
