{ inputs, host, ... }:
let
  classes = rec {
    null = [
    ];

    base = [
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
      ./sendmail.nix
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
      ./django-react.nix
      ./django.nix
      ./fastapi-svelte.nix
      ./fastapi.nix
      ./mailserver.nix
      ./mobilizon.nix
      ./mysql.nix
      ./nextcloud.nix
      ./nextcloud-rolf.nix
      ./nginx.nix
      ./postgresql.nix
      ./proxy.nix
      ./react.nix
      ./redis.nix
      ./svelte.nix
      ./tls-certs.nix
      ./tunnelservice.nix
      ./wordpress.nix
    ]
    ++ peer;
  };
in
{
  imports = classes.${host.class};
}
