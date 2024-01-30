{ user, inputs, isHM, ...}: let
  hm = {
    home.enableNixpkgsReleaseCheck = true;
    home.stateVersion = "22.11";
    programs.home-manager.enable = true;
  };
in if isHM then hm else {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager = {
    users.${user} = hm;
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
