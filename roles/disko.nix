{
  host,
  lib,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    ../hosts/${host.name}/disko.nix
    ../modules/preserve.nix
  ];

  sops.secrets.luks-key = { };
  boot = {
    initrd = {
      secrets."/luks-key" = config.sops.secrets.luks-key.path;
    };
  };
  my-nixos = {
    locksmith.luksDevice = "/dev/sda3";
    preserve = {
      enable = true;
      directories = [
        "/home"
      ]
      ++ (lib.optionals config.networking.networkmanager.enable [
        "/etc/NetworkManager"
      ]);
    };
  };
}
