{ system, inputs, isHM, ... }: let
  hm = {
    imports = [
      inputs.agenix.homeManagerModules.default
    ];
    home.packages = [
      inputs.agenix.packages.${system}.default
    ];
  };
in if isHM then hm else {
  imports = [
    inputs.agenix.nixosModules.default
  ];
  environment.systemPackages = [
    inputs.agenix.packages.${system}.default
  ];
}
