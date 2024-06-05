{ config
, host
, inputs
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk.hm;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options.enable = mkEnableOption (mdDoc "Configure home-manager for this user");
  };

in {
  options.ahbk.hm = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (eachUser != {}) {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [ ../hm-modules/all.nix ];
      users = mapAttrs (user: cfg: {
        programs.home-manager.enable = true;
        home = {
          enableNixpkgsReleaseCheck = true;
          stateVersion = host.stateVersion;
        };
      }) eachUser;
    };
  };
}
