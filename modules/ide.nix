{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.ide;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;
  eachHMUser = filterAttrs (user: cfg: config.my-nixos.hm.${user}.enable) eachUser;

  userOpts = {
    options = {
      enable = mkEnableOption "IDE for this user";
      postgresql = mkEnableOption "a postgres db with same name";
      mysql = mkEnableOption "a mysql db with same name";
    };
  };
in
{
  options.my-nixos.ide =
    with types;
    mkOption {
      description = "Set of users to be configured with IDE.";
      type = attrsOf (submodule userOpts);
      default = { };
    };

  config = mkIf (eachUser != { }) {
    home-manager.users = mapAttrs (user: cfg: {
      my-nixos-hm.ide = {
        enable = true;
        inherit (config.my-nixos.users.${user}) name email;
      };
    }) eachHMUser;

    programs.vim = {
      enable = true;
      defaultEditor = true;
    };

    environment.systemPackages = with pkgs; [
      sqlitebrowser
      python3
      payload-dumper-go
    ];

    programs.adb.enable = true;

    users.users = mapAttrs (user: cfg: { extraGroups = [ "adbusers" ]; }) eachUser;

    my-nixos.postgresql = mapAttrs (user: cfg: { ensure = cfg.postgresql; }) eachUser;
    my-nixos.mysql = mapAttrs (user: cfg: { ensure = cfg.mysql; }) eachUser;
  };
}
