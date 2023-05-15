{
  description = "This is my system";

  inputs = {
    nixpkgs = "git+file:/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      "friday" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        module = [ ./configuration.nix ];
      };
    };
  };
}
