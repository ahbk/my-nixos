{
  description = "my nixos";

  inputs = {
    nixpkgs.url = "github:kompismoln/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:ahbk/nixos-mailserver/relay";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    preservation.url = "github:nix-community/preservation";

    nixos-cli.url = "github:nix-community/nixos-cli";
    nixos-cli.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval-sync.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval-sync.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";

    kompismoln-site.url = "git+ssh://git@github.com/Kompismoln/website";
    kompismoln-site.inputs.nixpkgs.follows = "nixpkgs";

    sysctl-user-portal.url = "git+ssh://git@github.com/PelleHanspers/sysctl_userportal";
    sysctl-user-portal.inputs.nixpkgs.follows = "nixpkgs";

    klimatkalendern.url = "github:Kompismoln/klimatkalendern";
    klimatkalendern.inputs.nixpkgs.follows = "nixpkgs";

    klimatkalendern1.url = "github:Kompismoln/klimatkalendern";
    klimatkalendern1.inputs.nixpkgs.follows = "nixpkgs";

    klimatkalendern-dev.url = "github:Kompismoln/klimatkalendern/dev";
    klimatkalendern-dev.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      inherit (nixpkgs.lib) nixosSystem mapAttrs;
      inherit (home-manager.lib) homeManagerConfiguration;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      ids = import ./ids.nix;
      users = import ./users.nix;
      hosts = import ./hosts.nix;
      subnets = import ./subnets.nix;
      lib' = (import ./lib.nix) {
        inherit pkgs;
        lib = nixpkgs.lib;
      };
    in
    {
      homeConfigurations = mapAttrs (
        target: cfg:
        homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${cfg.system};
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [
            { home.stateVersion = cfg.stateVersion; }
            ./hm-modules/all.nix
            { inherit (cfg) my-nixos-hm; }
          ];
        }
      ) (import ./hm-hosts.nix);

      nixosConfigurations = mapAttrs (
        hostname: hostconf:
        nixosSystem {
          specialArgs = {
            host = hostconf // {
              name = hostname;
            };
            inherit
              inputs
              hosts
              ids
              users
              subnets
              lib'
              ;
          };
          modules = [
            ./modules/index.nix
            ./hosts/${hostname}/configuration.nix
          ];
        }
      ) hosts;

      devShells.${system}.default = pkgs.mkShellNoCC {
        shellHook = ''
          export BUILD_HOST=./
          PATH=$(pwd)/tools/bin:$PATH
        '';
      };

    };
}
