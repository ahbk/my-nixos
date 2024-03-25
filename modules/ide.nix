{ lib, config, pkgs, ... }: with lib;
let
  cfg = config.ahbk.ide;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options = {
      enable = mkEnableOption (mdDoc "Configure IDE for this user") // { default = true; };
      postgresql = mkEnableOption (mdDoc "Ensure user has a postgres db with same name") // { default = true; };
      mysql = mkEnableOption (mdDoc "Ensure user has a mysql db with same name") // { default = true; };
    };
  };

  hm = import ./ide-hm.nix;
in {
  options.ahbk.ide = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (eachUser != {}) {
    home-manager.users = mapAttrs (hm config.ahbk) eachUser;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    environment.systemPackages = with pkgs; [
      sqlitebrowser
      python3
      poetry
      payload-dumper-go
    ];

    programs.adb.enable = true;

    users.users = mapAttrs (user: cfg: { extraGroups = ["adbusers"]; }) eachUser;

    networking.hosts."127.0.0.2" = mapAttrsToList (user: cfg: user) eachUser;

    services.dnsmasq = {
      enable = false; # todo: conflicts with knot resolver
      settings.address = mapAttrsToList (user: cfg: "/.${user}/127.0.0.2") eachUser;
    };

    ahbk.postgresql = mapAttrs (user: cfg: { ensure = cfg.postgresql; }) eachUser;
    ahbk.mysql = mapAttrs (user: cfg: { ensure = cfg.mysql; }) eachUser;
  };
}
