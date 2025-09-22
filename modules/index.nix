rec {

  null = [
  ];

  base = [
    ./system.nix
    ./nix.nix
    ./locksmith.nix
    ./preserve.nix
  ];

  peer = [
    ./sops.nix
    ./ssh.nix
    ./wireguard.nix
    ./users.nix
    ./fail2ban.nix
    ./backup.nix
    ./backup-server.nix
    ./sendmail.nix
  ]
  ++ base;

  workstation = [
    ./hm.nix
    ./desktop-env.nix
    ./vd.nix
    ./ide.nix
    ./sendmail.nix
    ./shell.nix
    ./mysql.nix
    ./postgresql.nix
  ]
  ++ peer;

  webserver = [
    ./tls-certs.nix
    ./django-react.nix
    ./django-svelte.nix
    ./django.nix
    ./mysql.nix
    ./nginx.nix
    ./svelte.nix
    ./fastapi-svelte.nix
    ./fastapi.nix
    ./postgresql.nix
    ./wordpress.nix
    ./react.nix
    ./collabora.nix
    ./nextcloud.nix
    ./nextcloud-rolf.nix
    ./mobilizon.nix
    ./mailserver.nix
    ./tunnelservice.nix
  ]
  ++ peer;

  #extensions = [
  #  ../preserve.nix
  #]
  #+ base;
  #imports = [
  #../glesys-updaterecord.nix
  #../debug.nix
  #../monitor.nix
  #];
}
