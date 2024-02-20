{ inputs, pkgs, config, lib, nixpkgs, ... }: {
  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    ./chatddx.nix
    ./django.nix
    ./de.nix
    ./fastapi.nix
    ./ide.nix
    ./inadyn.nix
    ./mysql.nix
    ./nginx.nix
    ./postgresql.nix
    ./shell.nix
    ./svelte.nix
    ./user.nix
    ./vd.nix
    ./wordpress.nix
  ];

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
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
