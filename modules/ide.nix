{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my-nixos.ide;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;
  eachUserAsTopDomain = filterAttrs (user: cfg: cfg.userAsTopDomain) eachUser;

  userOpts = with types; {
    options = {
      enable = mkEnableOption "IDE for this user";
      postgresql = mkEnableOption "a postgres db with same name";
      mysql = mkEnableOption "a mysql db with same name";
      userAsTopDomain = mkEnableOption "username a top domain name in local network";
    };
  };
in {
  options.my-nixos.ide = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (eachUser != {}) {
    home-manager.users = mapAttrs (user: cfg: {
      my-nixos-hm.ide = {
        enable = true;
        inherit (config.my-nixos.user.${user}) name email;
      };
    }) eachUser;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    environment.systemPackages = with pkgs; [
      sqlitebrowser
      python3
      payload-dumper-go
    ];

    programs.adb.enable = true;

    users.users = mapAttrs (user: cfg: { extraGroups = ["adbusers"]; }) eachUser;

    networking.hosts."127.0.0.2" = mapAttrsToList (user: cfg: user) eachUser;

    services.dnsmasq = mkIf (eachUserAsTopDomain != {}) {
      enable = true;
      settings.address = mapAttrsToList (user: cfg: "/.${user}/127.0.0.2") eachUserAsTopDomain;
    };

    my-nixos.postgresql = mapAttrs (user: cfg: { ensure = cfg.postgresql; }) eachUser;
    my-nixos.mysql = mapAttrs (user: cfg: { ensure = cfg.mysql; }) eachUser;
  };
}
