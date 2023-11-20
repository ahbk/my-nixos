{ config, pkgs, inputs, ... }: {
  imports = [
    ./common-home.nix
  ];

  programs.helix = {
    enable = true;
    package = inputs.helix.packages."x86_64-linux".default;
  };

  home.packages = with pkgs; [
  ];
}
