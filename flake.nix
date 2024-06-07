{
  description = "my nixos";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, ... }@inputs:

  with inputs.nixpkgs.lib;
  with inputs.home-manager.lib;

  {
    homeConfigurations = mapAttrs (target: cfg: homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${cfg.system};
      extraSpecialArgs = { inherit inputs; };
      modules = [
        ./hm-modules/all.nix
        { inherit (cfg) my-nixos-hm; }
      ];
    }) (import ./hm-hosts.nix);

    nixosConfigurations = mapAttrs (hostname: host: nixosSystem {
      specialArgs = { inherit inputs host; };
      modules = [
        ./configurations/${hostname}-hardware.nix
        ./modules/all.nix
        ./configurations/${hostname}.nix
      ];
    }) (import ./hosts.nix);

    packages."x86_64-linux".options-doc = let
      pkgs' = import ./packages/all.nix {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
      };
    in pkgs'.options-doc;
  };
}
