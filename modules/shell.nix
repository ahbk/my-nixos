{
  config,
  host,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    flatten
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.shell;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = {
    options.enable = mkEnableOption "shell for this user";
  };
in
{
  options.my-nixos.shell =
    with types;
    mkOption {
      description = "Set of users to be configured with shell";
      type = attrsOf (submodule userOpts);
      default = { };
    };
  config = mkIf (eachUser != { }) {

    my-nixos.backup."backup.ahbk".paths = flatten (
      mapAttrsToList (user: cfg: [ "/home/${user}/.bash_history" ]) eachUser
    );

    home-manager.users = mapAttrs (user: cfg: { my-nixos-hm.shell.enable = true; }) eachUser;

    documentation.man.generateCaches = true;

    environment.systemPackages = with pkgs; [
      inputs.agenix.packages.${host.system}.default
      w3m
    ];
  };
}
