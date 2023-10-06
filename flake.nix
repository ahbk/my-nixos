{
  description = "my system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations."frans@seagull" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./seagull-home.nix ];
    };

    homeConfigurations."frans@blackbird" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./blackbird-home.nix ];
    };

    nixosConfigurations = {
      "friday" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./friday.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frans = import ./friday-home.nix; }
        ];
      };

      "jarvis" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./jarvis.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.frans = import ./jarvis-home.nix; }
        ];
      };
    };
  };
}
