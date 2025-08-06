{ inputs, ... }:
let
  users = import ../users.nix;
in
{
  imports = [
    ./helsinki-disko.nix
  ];

  boot.loader.grub = {
    enable = true;
  };

  sops = {
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  my-nixos = {
    users = with users; {
      inherit admin alex;
    };
  };

  system.stateVersion = "25.05";
}
