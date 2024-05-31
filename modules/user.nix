{ config
, lib
, pkgs
, ...
}:

with lib;

let
  lib' = (import ../lib.nix) { inherit lib pkgs; };
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
        type = listOf path;
        default = [];
      };
      email = mkOption {
        type = str;
      };
      groups = mkOption {
        type = listOf str;
        default = [];
      };
    };
  };

  hm = import ./user-hm.nix;  
in {

  options.ahbk.user = with types; mkOption {
    type = attrsOf (submodule userOpts);
    default = {};
  };

  config = mkIf (cfg != {}) {
    age.secrets = mapAttrs' (user: cfg: (
      nameValuePair "linux-passwd-hashed-${user}" {
      file = ../secrets/linux-passwd-hashed-${user}.age;
      owner = user;
      group = user;
    })) eachUser;

    users = (lib'.mergeAttrs (user: cfg: {
      users.${user} = {
        uid = cfg.uid;
        isNormalUser = true;
        group = user;
        extraGroups = cfg.groups;
        hashedPasswordFile = config.age.secrets."linux-passwd-hashed-${user}".path;
        openssh.authorizedKeys.keyFiles = cfg.keys;
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
