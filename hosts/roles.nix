# hosts/roles.nix
{
  inputs,
  host,
  lib,
  ...
}:
let
  roles = rec {
    base = [
      ./${host.name}/configuration.nix
      ../modules/locksmith.nix
      ../modules/nix.nix
      ../modules/preserve.nix
      ../modules/system.nix
    ];

    peer = [
      {
        my-nixos.tls-certs = [ "km" ];
      }
      ../modules/fail2ban.nix
      ../modules/sendmail.nix
      ../modules/sops.nix
      ../modules/ssh.nix
      ../modules/tls-certs.nix
      ../modules/users.nix
      ../modules/wireguard.nix
    ]
    ++ base;

    workstation = [
      {
        nixpkgs.overlays = [
          (import ../overlays/workstation.nix { inherit inputs; })
        ];
      }
      ../modules/desktop-env.nix
      ../modules/hm.nix
      ../modules/ide.nix
      ../modules/mysql.nix
      ../modules/postgresql.nix
      ../modules/shell.nix
      ../modules/vd.nix
    ]
    ++ peer;

    webserver = [
      {
        nixpkgs.overlays = [
          (import ../overlays/webserver.nix { inherit inputs; })
        ];
      }
      ../modules/collabora.nix
      ../modules/dns-hints.nix
      ../modules/django-react.nix
      ../modules/django.nix
      ../modules/egress-proxy.nix
      ../modules/fastapi-svelte.nix
      ../modules/fastapi.nix
      ../modules/mobilizon.nix
      ../modules/monitor.nix
      ../modules/mysql.nix
      ../modules/nextcloud.nix
      ../modules/nextcloud-rolf.nix
      ../modules/nginx.nix
      ../modules/postgresql.nix
      ../modules/react.nix
      ../modules/redis.nix
      ../modules/reverse-tunnel.nix
      ../modules/svelte.nix
      ../modules/tls-certs.nix
      ../modules/wordpress.nix
    ]
    ++ peer;

    mailserver = [
      ../modules/mailserver.nix
    ]
    ++ peer;
  };
in
{
  imports = lib.optionals (lib.hasAttr "roles" host) lib.concatMap (role: roles.${role}) host.roles;
}
