{ config
, lib
, ...
}:

with lib;

let
  cfg = config.ahbk-hm.user;
in {
  options.ahbk-hm.user = with types; {
    enable = mkEnableOption (mkDoc "Configure home-manager for this user");
    name = mkOption { type = str; };
  };

  config = mkIf cfg.enable {
    programs.home-manager.enable = true;

    programs.ssh = {
      enable = true;
    };

    home = {
      enableNixpkgsReleaseCheck = true;
      stateVersion = "22.11";
      username = cfg.name;
      homeDirectory = lib.mkDefault /home/${cfg.name};
    };
  };
}
