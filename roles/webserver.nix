{ inputs, ... }:
{
  imports = [
    ../modules/collabora.nix
    ../modules/dns-hints.nix
    ../modules/django-react.nix
    ../modules/django.nix
    ../modules/egress-proxy.nix
    ../modules/fail2ban.nix
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
  ];
  nixpkgs.overlays = [
    (import ../overlays/webserver.nix { inherit inputs; })
  ];
  my-nixos = {
    reverse-tunnel.enable = true;
    egress-proxy.enable = true;
    fail2ban.enable = true;
    nginx = {
      enable = true;
      monitor = false;
    };
  };

}
