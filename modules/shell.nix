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
    hasAttr
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos.shell;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;
  eachHMUser = filterAttrs (
    user: cfg: hasAttr user config.my-nixos.hm && config.my-nixos.hm.${user}.enable
  ) eachUser;

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

    my-nixos.backup.km.paths = flatten (
      mapAttrsToList (user: cfg: [ "/home/${user}/.bash_history" ]) eachUser
    );

    home-manager.users = mapAttrs (user: cfg: { my-nixos-hm.shell.enable = true; }) eachHMUser;

    # This takes to long time to be worth it
    # enable only when needed or update manually
    #documentation.man.generateCaches = true;

    services.nixos-cli = {
      enable = true;
    };
    mailserver.fqdn = "mail.kompismoln.se";

    environment.systemPackages = with pkgs; [
      inputs.agenix.packages.${host.system}.default
      inputs.nixos-anywhere.packages.${host.system}.default
      jq
      yq-go
      ssh-to-age
      sops
      age
      w3m
      git
      vim
      tree
      nixos-facter
    ];
  };
}
