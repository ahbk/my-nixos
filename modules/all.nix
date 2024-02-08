{ inputs, pkgs, config, lib, nixpkgs, ... }: {
  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    ./django.nix
    ./de.nix
    ./fastapi.nix
    ./ide.nix
    ./inadyn.nix
    ./mysql.nix
    ./postgresql.nix
    ./shell.nix
    ./svelte.nix
    ./user.nix
    ./vd.nix
    ./wordpress.nix
  ];

  time.timeZone = "Europe/Stockholm";
  system.stateVersion = "20.03";
  services.openssh.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  nix = {
    package = pkgs.nixFlakes;
    registry.nixpkgs.flake = nixpkgs;
    channel.enable = false;
    settings.nix-path = lib.mkForce "nixpkgs=/etc/nix/inputs/nixpkgs";
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  environment.etc."nix/inputs/nixpkgs".source = "${nixpkgs}";


  networking.networkmanager.enable = true;
  users.users = lib.mapAttrs(user: cfg: { extraGroups = [ "networkmanager" ]; }) config.ahbk.user;

  fonts.packages = with pkgs; [
    source-code-pro
    hackgen-nf-font
  ];
}
