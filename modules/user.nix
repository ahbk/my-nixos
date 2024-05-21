{ config
, lib
, lib'
, ...
}:

with lib;

let
  cfg = config.ahbk.user;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options = {
      enable = mkEnableOption (mdDoc "Configure this user") // {
        default = true;
      };
      uid = mkOption {
        type = int;
      };
      name = mkOption {
        type = str;
      };
      keys = mkOption {
        type = listOf str;
        default = [];
      };
      email = mkOption {
        type = str;
      };
      groups = mkOption {
        type = listOf str;
      };
    };
  };

  hm = import ./user-hm.nix;  
in {

  options.ahbk.user = with types; mkOption {
    type = attrsOf (submodule userOpts);
  };

  config = mkIf (cfg != {}) {
    age.secrets = mapAttrs' (user: cfg: (
      nameValuePair "${user}-pw" {
      file = ../secrets/${user}-pw.age;
      owner = user;
      group = user;
    })) eachUser;

    users = (lib'.mergeAttrs (user: cfg: {
      users.${user} = {
        uid = cfg.uid;
        isNormalUser = true;
        group = user;
        extraGroups = cfg.groups;
        hashedPasswordFile = config.age.secrets."${user}-pw".path;
        openssh.authorizedKeys.keys = cfg.keys;
      };
      groups.${user}.gid = config.users.users.${user}.uid;
    }) eachUser) // {
      mutableUsers = false;
    };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    home-manager.users = mapAttrs (hm config.ahbk) eachUser;
  };
}
