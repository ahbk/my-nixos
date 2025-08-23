{
  description = "my nixos";

  inputs = {
    nixpkgs.url = "github:kompismoln/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:ahbk/nixos-mailserver/relay";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";

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
      domain = "km";
      buildHost = "stationary";

      ids = import ./ids.nix;
      users = import ./users.nix;
      hosts = import ./hosts.nix;
      lib' = (import ./lib.nix) {
        inherit pkgs;
        lib = nixpkgs.lib;
      };
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
            inherit
              inputs
              ids
              users
              hosts
              lib'
              ;
            host = cfg;
          };
          modules = [
            ./modules/all.nix
            { facter.reportPath = ./hosts/${cfg.name}/facter.json; }
            ./hosts/${cfg.name}/configuration.nix
            { sops.defaultSopsFile = ./hosts/${cfg.name}/secrets.yaml; }
          ];
        }
      ) hosts;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          (pkgs.writeShellScriptBin "deploy" ''
            #!/usr/bin/env bash
            nixos-rebuild switch --ask-sudo-password --flake ./#$1 \
            --target-host $1.${domain} --build-host ${buildHost}.${domain}
          '')
          (pkgs.writeShellScriptBin "deploy-test" ''
            #!/usr/bin/env bash
            nixos-rebuild test --ask-sudo-password --flake ./#$1 \
            --target-host $1.${domain} --build-host ${buildHost}.${domain}
          '')
          (pkgs.writeShellScriptBin "switch" ''
            #!/usr/bin/env bash
            nixos-rebuild switch --use-remote-sudo --show-trace --verbose \
            --build-host ${buildHost}.${domain};
          '')
          (pkgs.writeShellScriptBin "dirty-ssh" ''
            #!/usr/bin/env bash
            ssh -o StrictHostKeyChecking=no \
            -o GlobalKnownHostsFile=/dev/null \
            -o UserKnownHostsFile=/dev/null \
            $1
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
