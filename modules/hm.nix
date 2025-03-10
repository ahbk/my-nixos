{
  config,
  host,
  inputs,
  lib,
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

  cfg = config.my-nixos.hm;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = {
    options.enable = mkEnableOption "home-manager for this user";
  };
in
{
  options.my-nixos.hm =
    with types;
    mkOption {
      description = "Set of users to be configured with home-manager.";
      type = attrsOf (submodule userOpts);
      default = { };
    };

  config = mkIf (eachUser != { }) {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs;
      };
      sharedModules = [ ../hm-modules/all.nix ];
      users = mapAttrs (user: cfg: {
        home.stateVersion = host.stateVersion;
        home.username = user;
      }) eachUser;
    };
  };
}
