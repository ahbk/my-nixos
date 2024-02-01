{ pkgs, user, isHM, ... }: let
  hm = {
    home.packages = with pkgs; [ 
      mkcert
      black
      nodejs
      node2nix
      hugo
      xh
      yarn
      php
    ];
  };
in if isHM then hm else {
  imports = [
    ./mysql.nix
    ./postgresql.nix
  ];

  home-manager.users.${user} = hm;

  environment.systemPackages = with pkgs; [
    (sqlite.override { interactive = true; })
    python3
    poetry
    sqlitebrowser
  ];

  fonts.packages = with pkgs; [
    source-code-pro
    hackgen-nf-font
  ];

  ahbk.mysql.${user}.ensure = true;
  ahbk.postgresql.${user}.ensure = true;
}
