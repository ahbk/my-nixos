{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.my-nixos.preserve;

  # Piggyback on preservation's options for files and directories
  preserveAtOptions = options.preservation.preserveAt.type.nestedTypes.elemType.getSubOptions [ ];
in
{
  options.my-nixos.preserve = {
    inherit (preserveAtOptions) files directories;
    enable = mkEnableOption ''ephemeral root on this host'';
    storage = mkOption {
      description = "Root for permanent storage";
      type = types.str;
      default = "/srv/storage";
    };
  };

  config = mkIf cfg.enable {

    fileSystems.${cfg.storage}.neededForBoot = true;

    preservation = {
      enable = true;
      preserveAt.${cfg.storage} = {
        directories = [
          "/var/lib/nixos"
          "/var/lib/systemd"
        ]
        ++ cfg.directories;
        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
        ]
        ++ cfg.files;
      };
    };

    systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

    boot.initrd.systemd = {
      enable = true;
      services."format-root" = {
        enable = true;
        description = "Format the root LV partition at boot";
        unitConfig = {
          DefaultDependencies = "no";
          Requires = "dev-pool-root.device";
          After = "dev-pool-root.device";
          Before = "sysroot.mount";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.e2fsprogs}/bin/mkfs.ext4 -F /dev/pool/root";
        };
        wantedBy = [ "initrd.target" ];
      };

    };
  };
}
