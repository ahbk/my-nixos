{
  description = "my nixos";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/my-nixos";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:ahbk/nixos-mailserver/relay-domains";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";

    sysctl-user-portal.url = "git+ssh://git@github.com/PelleHanspers/sysctl_userportal";
    sysctl-user-portal.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (nixpkgs.lib) nixosSystem mapAttrs;
      inherit (home-manager.lib) homeManagerConfiguration;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

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
        hostname: host:
        nixosSystem {
          specialArgs = {
            inherit inputs host;
          };
          modules = [
            ./configurations/${hostname}-hardware.nix
            ./modules/all.nix
            ./configurations/${hostname}.nix
          ];
        }
      ) (import ./hosts.nix);

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          (pkgs.writeShellScriptBin "deploy" ''
            #!/usr/bin/env bash
            nixos-rebuild switch --use-remote-sudo --flake ${self} --build-host $1 --target-host $1
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
