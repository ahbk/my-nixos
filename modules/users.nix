{
  config,
  lib,
  lib',
  org,
  pkgs,
  ...
}:

let
  cfg = config.my-nixos.users;
  eachUser = lib.filterAttrs (user: cfg: cfg.enable) cfg;

  userOpts =
    { name, config, ... }:
    {
      options = {
        enable = lib.mkEnableOption "this user" // {
          default = true;
        };
        passwd = lib.mkEnableOption "password" // {
          default = config.class == "user";
        };
        publicKey = lib.mkEnableOption "public key" // {
          default = true;
        };
        class = lib.mkOption {
          description = "user's entity class";
          default = "user";
          type = lib.types.enum [
            "user"
            "service"
            "system"
          ];
        };
        description = lib.mkOption {
          default = name;
          type = lib.types.str;
        };
        home = lib.mkEnableOption "force home at /var/lib for system users";
        shell = lib.mkEnableOption "force bash shell for system users";
        email = lib.mkOption {
          description = "user's primary email";
          default = "${name}@${org.domain}";
          type = with lib.types; nullOr str;
        };
        groups = lib.mkOption {
          description = "user's extra groups";
          type = with lib.types; listOf str;
          default = [ ];
        };
      };
    };
in
{
  options.my-nixos.users = lib.mkOption {
    description = "Set of users to be configured.";
    type = with lib.types; attrsOf (submodule userOpts);
    default = { };
  };

  config = lib.mkIf (cfg != { }) {
    users.mutableUsers = false;

    sops.secrets = lib.mapAttrs' (
      user: userCfg:
      lib.nameValuePair "${user}/passwd-sha512" {
        neededForUsers = true;
        sopsFile = ../enc/${userCfg.class}-${user}.yaml;
      }
    ) (lib.filterAttrs (user: userCfg: userCfg.passwd) eachUser);

    users.users = lib.mapAttrs (
      user: userCfg:
      let
        isNormalUser = userCfg.class == "user";
        publicKey = ../public-keys/${userCfg.class}-${user}-ssh-key.pub;
        passwordFile = config.sops.secrets."${user}/passwd-sha512".path;
      in
      {
        inherit isNormalUser;
        description = userCfg.description;
        uid = lib'.ids.${user}.uid;
        isSystemUser = !isNormalUser;
        shell = lib.mkIf (!isNormalUser && userCfg.shell) pkgs.bash;
        home = lib.mkIf (!isNormalUser && userCfg.home) "/var/lib/${user}";
        group = user;
        extraGroups = userCfg.groups;
        openssh.authorizedKeys.keyFiles = lib.mkIf userCfg.publicKey [ publicKey ];
        hashedPasswordFile = lib.mkIf userCfg.passwd passwordFile;
      }
    ) eachUser;

    users.groups = lib.mapAttrs (name: _: {
      gid = lib'.ids.${name}.uid;
    }) eachUser;
  };
}
