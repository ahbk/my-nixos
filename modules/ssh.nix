{ user, ... }: {
  services.openssh.enable = true;
  users.users.${user}.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alexander.holmback@gmail.com" ];
}
