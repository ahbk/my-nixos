{
  description = "my nixos";

  inputs = {
    nixpkgs.url = "github:Kompismoln/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:ahbk/nixos-mailserver/relay";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";

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
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      inherit (nixpkgs.lib) nixosSystem mapAttrs;
      inherit (home-manager.lib) homeManagerConfiguration;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      ids = import ./ids.nix;

    in
    rec {
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
        name: cfg:
        nixosSystem {
          specialArgs = {
            inherit inputs ids;
            host = cfg;
          };
          modules = [
            ./modules/all.nix
            ./hosts/${cfg.name}/hardware-configuration.nix
            ./hosts/${cfg.name}/configuration.nix
          ];
        }
      ) (import ./hosts.nix);

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          (pkgs.writeShellScriptBin "deploy" ''
            #!/usr/bin/env bash
            nixos-rebuild switch --use-remote-sudo --flake ./ --build-host $1 --target-host $1
          '')
          (pkgs.writeShellScriptBin "switch" ''
            #!/usr/bin/env bash
            nixos-rebuild switch --use-remote-sudo --show-trace --verbose;
          '')
        ];
      };

      packages.${system} = {
        default = nixosConfigurations.laptop.config.system.build.nixos-rebuild;

        options-doc =
          let
            pkgs' = import ./packages/all.nix { pkgs = nixpkgs.legacyPackages.${system}; };
          in
          pkgs'.options-doc;
      };
    };
}
