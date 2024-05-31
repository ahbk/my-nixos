{
  description = "my system";

  inputs = {
    nixpkgs.url = "github:ahbk/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
    nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    nixpak.url = "github:nixpak/nixpak";
    nixpak.inputs.nixpkgs.follows = "nixpkgs";

    sverigesval.url = "git+ssh://git@github.com/ahbk/sverigesval.org";
    sverigesval.inputs.nixpkgs.follows = "nixpkgs";

    chatddx.url = "git+ssh://git@github.com/LigninDDX/chatddx";
    chatddx.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # wkhtmltopdf is broken and unsafe, this is the context for running wkhtmltopdf as a nixpak
    nixpkgs-wkhtmltopdf.url = "github:NixOS/nixpkgs/c8d822252b86022a71dcc4f0f48bc869ef446401";
    nixpkgs-wkhtmltopdf.flake = false;
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
        { inherit (cfg) ahbk-hm; }
      ];
      }) (import ./hm-hosts.nix);

    nixosConfigurations = mapAttrs (hostname: cfg: nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configurations/${hostname}-hardware.nix
        ./modules/all.nix
        ./configurations/${hostname}.nix
      ];
    }) (import ./hosts.nix);
  };
}
