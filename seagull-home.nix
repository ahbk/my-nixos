{ config, pkgs, inputs, ... }: {
  imports = [
    ./common-home.nix
  ];

  programs.helix = {
    enable = false;
    package = inputs.helix.packages."x86_64-linux".default;
  };

  home.packages = with pkgs; [
  ];
}
