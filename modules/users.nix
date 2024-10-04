{
  config,
  lib,
  pkgs,
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

  lib' = (import ../lib.nix) { inherit lib pkgs; };
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
      };
    };

    my-nixos.monit.config = ''
      check process sshd with pidfile /var/run/sshd.pid
          start program  "${pkgs.systemd}/bin/systemctl start sshd"
          stop program  "${pkgs.systemd}/bin/systemctl stop sshd"
          if failed port 22 protocol ssh for 2 cycles then restart
    '';

    services.fail2ban.jails = {
      sshd.settings = {
        filter = "sshd[mode=aggressive]";
      };
    };
  };
}
