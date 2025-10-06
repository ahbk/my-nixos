{
  config,
  lib,
  ids,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  cfg = config.my-nixos.locksmith;

  locksmithPkg =
    pkgs.runCommand "locksmith"
      {
        buildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        cp ${../tools/remote/locksmith.sh} $out/bin/locksmith-unwrapped
        chmod +x $out/bin/locksmith-unwrapped

        makeWrapper $out/bin/locksmith-unwrapped $out/bin/locksmith \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.cryptsetup
              pkgs.age
            ]
          } \
          --set LUKS_DEVICE "${cfg.luksDevice}" \
          --set KEY_FILE "${config.sops.age.keyFile}"
      '';
in
{
  options.my-nixos.locksmith = {
    enable = mkEnableOption "user locksmith";
    luksDevice = mkOption {
      type = types.str;
    };
  };

  config = mkIf (cfg.enable) {
    environment.systemPackages = [ locksmithPkg ];
    users.users.locksmith = {
      isSystemUser = true;
      shell = pkgs.bash;

      openssh.authorizedKeys.keyFiles = [
        ../public-keys/service-locksmith-ssh-key.pub
      ];
      uid = ids.locksmith.uid;
      group = "locksmith";
    };

    users.groups.locksmith = {
      gid = ids.locksmith.uid;
    };

    services.openssh = {
      extraConfig = ''
        Match User locksmith
          ForceCommand sudo ${locksmithPkg}/bin/locksmith \$SSH_ORIGINAL_COMMAND
      '';
    };

    security.sudo.extraRules = [
      {
        users = [ "locksmith" ];
        commands = [
          {
            command = "${locksmithPkg}/bin/locksmith *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

  };
}
