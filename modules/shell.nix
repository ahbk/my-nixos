{ lib, config, inputs, system, ... }: with lib;
let
  cfg = config.ahbk.shell;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options.enable = mkEnableOption (mdDoc "Configure shell for this user") // {
      default = true;
    };
  };

  hm = import ./shell-hm.nix;
in {
  options.ahbk.shell = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };
  config = mkIf (eachUser != {}) {
    home-manager.users = mapAttrs (hm config.ahbk) eachUser;
    environment.systemPackages = [
      inputs.agenix.packages.${system}.default
    ];

  };
}
