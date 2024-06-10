{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    filterAttrs
    types
    mkEnableOption
    mkOption
    mkIf
    mapAttrs
    hasAttr
    mapAttrs'
    nameValuePair
    ;
  lib' = (import ../lib.nix) { inherit lib pkgs; };
  cfg = config.my-nixos.user;
  eachUser = filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts = with types; {
    options = {
      enable = mkEnableOption "this user" // {
        default = true;
      };
      uid = mkOption {
        description = "User id.";
        type = int;
      };
      name = mkOption {
        description = "User name.";
        type = str;
      };
      keys = mkOption {
        description = "Public SSH keys.";
        type = listOf path;
        default = [ ];
      };
      email = mkOption {
        description = "User email.";
        type = str;
      };
      groups = mkOption {
        description = "User groups.";
        type = listOf str;
        default = [ ];
      };
    };
  };
in
{

  options.my-nixos.user =
    with types;
    mkOption {
      description = "Set of users to be configured.";
      type = attrsOf (submodule userOpts);
      default = { };
    };

  config = mkIf (cfg != { }) {
    home-manager.users =
      mapAttrs
        (user: cfg: {
          my-nixos-hm.user = {
            enable = true;
            name = user;
          };
        })
        (
          filterAttrs (
            user: cfg: hasAttr user config.my-nixos.hm && config.my-nixos.hm.${user}.enable
          ) eachUser
        );

    age.secrets = mapAttrs' (
      user: cfg:
      (nameValuePair "linux-passwd-hashed-${user}" {
        file = ../secrets/linux-passwd-hashed-${user}.age;
        owner = user;
        group = user;
      })
    ) eachUser;

    users =
      (lib'.mergeAttrs (user: cfg: {
        users.${user} = {
          uid = cfg.uid;
          isNormalUser = true;
          group = user;
          extraGroups = cfg.groups;
          hashedPasswordFile = config.age.secrets."linux-passwd-hashed-${user}".path;
          openssh.authorizedKeys.keyFiles = cfg.keys;
        };
        groups.${user}.gid = config.users.users.${user}.uid;
      }) eachUser)
      // {
        mutableUsers = false;
      };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        #ListenAddress = host.address;
      };
    };
  };
}
