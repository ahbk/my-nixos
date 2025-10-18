{
  imports = [
    ../modules/locksmith.nix
    ../modules/nix.nix
    ../modules/preserve.nix
    ../modules/sops.nix
    ../modules/ssh.nix
    ../modules/tls-certs.nix
    ../modules/users.nix
    ../modules/wireguard.nix
  ];

  my-nixos = {
    users.admin = {
      class = "user";
      groups = [ "wheel" ];
    };
    tls-certs = [ "km" ];
    locksmith.enable = true;
    sops.enable = true;
    ssh.enable = true;
  };
}
