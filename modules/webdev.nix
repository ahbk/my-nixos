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

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    ensureDatabases = [ user ];
    ensureUsers = [
      {
        name = user;
        ensurePermissions = {
          "${user}.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    ensureDatabases = [ user ];
    ensureUsers = [
      {
        name = user;
        ensureDBOwnership = true;
      }
    ];
  };

}
