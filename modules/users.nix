{
  config,
  lib,
  lib',
  ...
}:

let
  inherit (lib)
    filterAttrs
    hasAttr
    mapAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  cfg = config.my-nixos.users;
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
      aliases = mkOption {
        description = "Emails this user manages.";
        type = listOf str;
        default = [ ];
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

  options.my-nixos.users =
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
            uid = cfg.uid;
          };
        })
        (
          filterAttrs (
            user: cfg: hasAttr user config.my-nixos.hm && config.my-nixos.hm.${user}.enable
          ) eachUser
        );

    sops.secrets = mapAttrs' (
      user: cfg:
      (nameValuePair "${user}/passwd-hashed") {
        neededForUsers = true;
        sopsFile = ../users/${user}-enc.yaml;
      }
    ) eachUser;

    users =
      (lib'.mergeAttrs (user: cfg: {
        users.${user} = {
          uid = cfg.uid;
          isNormalUser = true;
          group = user;
          extraGroups = cfg.groups;
          hashedPasswordFile = config.sops.secrets."${user}/passwd-hashed".path;
          openssh.authorizedKeys.keyFiles = cfg.keys;
        };
        groups.${user}.gid = config.users.users.${user}.uid;
      }) eachUser)
      // {
        mutableUsers = false;
      };

    services.openssh = {
      enable = true;
      extraConfig = lib.concatStrings (
        lib.mapAttrsToList (user: cfg: ''
          Match User ${user}
            PasswordAuthentication no
            ChallengeResponseAuthentication no
            KbdInteractiveAuthentication no
        '') eachUser
      );
    };

    services.fail2ban.jails = {
      sshd.settings = {
        filter = "sshd[mode=aggressive]";
      };
    };
  };
}
