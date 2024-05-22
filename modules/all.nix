{ inputs
, lib
, nixpkgs
, pkgs
, theme
, ...
}:
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-mailserver.nixosModules.default
    ./backup.nix
    ./chatddx.nix
    ./django.nix
    ./de.nix
    ./fastapi.nix
    ./glesys-updaterecord.nix
    ./ide.nix
    ./laptop.nix
    ./mail-client.nix
    ./mail-server.nix
    ./mysql.nix
    ./nginx.nix
    ./odoo.nix
    ./postgresql.nix
    ./shell.nix
    ./svelte.nix
    ./sverigesval.nix
    ./user.nix
    ./vd.nix
    ./wg-client.nix
    ./wg-server.nix
    ./wordpress.nix
  ];

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs theme; };
  };

  nix = {
    package = pkgs.nixFlakes;
    registry.nixpkgs.flake = nixpkgs;
    channel.enable = false;
    settings = {
      nix-path = lib.mkForce "nixpkgs=/etc/nix/inputs/nixpkgs";
      experimental-features = [ "nix-command" "flakes" ];
    };
  };
  environment.etc."nix/inputs/nixpkgs".source = "${nixpkgs}";
}
