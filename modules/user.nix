{ lib, lib', config, options, ... }: with lib;
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
      shell = (options.ahbk.shell.type.getSubOptions []);
      ide = (options.ahbk.ide.type.getSubOptions []);
      de = (options.ahbk.de.type.getSubOptions []);
      vd = (options.ahbk.vd.type.getSubOptions []);
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

    ahbk.shell = mapAttrs (user: cfg: cfg.shell) eachUser;
    ahbk.ide = mapAttrs (user: cfg: cfg.ide) eachUser;
    ahbk.de = mapAttrs (user: cfg: cfg.de) eachUser;
    ahbk.vd = mapAttrs (user: cfg: cfg.vd) eachUser;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
      };
    };

    home-manager.users = mapAttrs (hm config.ahbk) eachUser;
  };
}
