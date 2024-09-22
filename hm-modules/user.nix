{ config, lib, ... }:

let
  inherit (lib)
    hm
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.my-nixos-hm.user;
in
{
  options.my-nixos-hm.user = with types; {
    enable = mkEnableOption "home-manager for this user";
    name = mkOption {
      description = "Name for the user.";
      type = str;
    };
  };

  config = mkIf cfg.enable {
    programs.home-manager.enable = true;
    nix.settings = {
      use-xdg-base-directories = true;
    };
    home = {
      username = cfg.name;
      homeDirectory = mkDefault /home/${cfg.name};
      activation = {
        prune-home = hm.dag.entryAfter ["writeBoundary"] ''
            rm -rf /home/${cfg.name}/.nix-defexpr
            rm -rf /home/${cfg.name}/.nix-profile
        '';
      };
    };
  };
}
