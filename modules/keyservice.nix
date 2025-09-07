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
  cfg = config.my-nixos.keyservice;

  keyservicePkg =
    pkgs.runCommand "keyservice"
      {
        buildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        cp ${../tools/keyservice.sh} $out/bin/keyservice-unwrapped
        chmod +x $out/bin/keyservice-unwrapped

        makeWrapper $out/bin/keyservice-unwrapped $out/bin/keyservice \
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
  options.my-nixos.keyservice = {
    enable = mkEnableOption "user keyservice";
    luksDevice = mkOption {
      type = types.str;
    };
  };

  config = mkIf (cfg.enable) {
    environment.systemPackages = [ keyservicePkg ];
    users.users.keyservice = {
      isSystemUser = true;
      shell = pkgs.bash;

      openssh.authorizedKeys.keyFiles = [
        ../public-keys/user-keyservice-ssh-key.pub
      ];
      uid = ids.keyservice.uid;
      group = "keyservice";
    };

    users.groups.keyservice = {
      gid = ids.keyservice.uid;
    };

    services.openssh = {
      enable = true;

      extraConfig = ''
        Match User keyservice
          ForceCommand sudo ${keyservicePkg}/bin/keyservice \$SSH_ORIGINAL_COMMAND
      '';
    };

    security.sudo.extraRules = [
      {
        users = [ "keyservice" ];
        commands = [
          {
            command = "${keyservicePkg}/bin/keyservice *";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

  };
}
