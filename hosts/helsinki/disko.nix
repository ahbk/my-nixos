{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings = {
                  keyFile = "/luks-key";
                  allowDiscards = true;
                };
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "5G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
                "noatime"
                "nodiratime"
              ];
            };
          };
          swap = {
            size = "8G";
            content = {
              type = "swap";
            };
          };
          persistent = {
            size = "60%VG";
            content = {
              type = "btrfs";
              subvolumes = {
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "space_cache=v2"
                  ];
                };
                "@storage" = {
                  mountpoint = "/srv/storage";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "space_cache=v2"
                  ];
                };
                "@backup" = {
                  mountpoint = "/srv/backup";
                  mountOptions = [
                    "compress=no"
                    "noatime"
                    "space_cache=v2"
                    "ro"
                  ];
                };
              };
            };
          };
          share = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/srv/share";
              mountOptions = [
                "defaults"
                "noatime"
                "nodiratime"
              ];
            };
          };
        };
      };
    };
  };
}
