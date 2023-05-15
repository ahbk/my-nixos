{
  description = "This is my system";

  inputs = {
    nixpkgs.url = "git+file:/etc/nixos/nixpkgs";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      "friday" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
      };
    };
  };
}
