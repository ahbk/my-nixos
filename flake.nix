{
  description = "my system";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:ahbk/nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    rolf.url = "git+ssh://git@github.com/ahbk/rolf";
    rolf.inputs.nixpkgs.follows = "nixpkgs";

    esse.url = "git+ssh://git@github.com/ahbk/esse";
    esse.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    user = "frans";
  in {
    homeConfigurations."${user}@seagull" = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs user system; isHM = true; };
      modules = [
        ./modules/agenix.nix
        ./modules/git.nix
        ./modules/hm.nix
        ./modules/nvim.nix
        ./modules/shell.nix
        ./modules/tmux.nix
        ./modules/webdev.nix
      ];
    };

    nixosConfigurations = rec {

      # nixos@10.233.2.2 for testing
      # nixos-container create test ~/Desktop/nixos
      container = test;
      test = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs user system; isHM = false; };
        modules = [
          ./modules/agenix.nix
          ./modules/container.nix
          ./modules/ssh.nix
          ./modules/system.nix
          ./modules/user.nix
        ];
      };

      friday = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs user system; isHM = false; };
        modules = [
          ./modules/friday.nix
          ./modules/agenix.nix
          ./modules/battery.nix
          ./modules/boot.nix
          ./modules/bitwarden.nix
          ./modules/containers.nix
          ./modules/design.nix
          ./modules/foot.nix
          ./modules/git.nix
          ./modules/hm.nix
          ./modules/hypr.nix
          ./modules/light.nix
          ./modules/nix.nix
          ./modules/misc.nix
          ./modules/nm.nix
          ./modules/nvim.nix
          ./modules/pipefix.nix
          ./modules/shell.nix
          ./modules/sound.nix
          ./modules/ssh.nix
          ./modules/system.nix
          ./modules/tmux.nix
          ./modules/torrent.nix
          ./modules/user.nix
          ./modules/webdev.nix
          ./modules/xdg.nix
        ];
      };

      jarvis = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs user system; isHM = false; };
        modules = [
          ./modules/jarvis.nix
          ./modules/agenix.nix
          ./modules/boot.nix
          ./modules/hm.nix
          ./modules/inadyn.nix
          ./modules/nix.nix
          ./modules/nvim.nix
          ./modules/shell.nix
          ./modules/ssh.nix
          ./modules/system.nix
          ./modules/sites.nix
          ./modules/tmux.nix
          ./modules/user.nix
        ];
      };
    };
  };
}
