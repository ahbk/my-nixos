{ config, lib, ... }:

let
  inherit (lib)
    types
    mkIf
    mkEnableOption
    mkOption
    ;
  cfg = config.my-nixos-hm.user;
in
{
  options.my-nixos-hm.user = with types; {
    enable = mkEnableOption "home-manager for this user";
    name = mkOption { type = str; };
  };

  config = mkIf cfg.enable {
    programs.home-manager.enable = true;
    home = {
      username = cfg.name;
      homeDirectory = lib.mkDefault /home/${cfg.name};
    };
  };
}
