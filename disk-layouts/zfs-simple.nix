{ device ? "/dev/vda" }: {
  disk = {
    vda = {
      type = "disk";
      device = "/dev/vda";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            name = "boot";
            type = "partition";
            start = "0";
            end = "1M";
            part-type = "primary";
            flags = ["bios_grub"];
          }
          {
            type = "partition";
            name = "ESP";
            start = "1M";
            end = "256M";
            fs-type = "fat32";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          }
          {
            type = "partition";
            name = "zfs";
            start = "256M";
            end = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          }
        ];
      };
    };
  };
  zpool = {
    rpool = {
      type = "zpool";
      mode = "";
      rootFsOptions = {
        compression = "zstd";
      };
      datasets = {
        "root" = {
          zfs_type = "filesystem";
          mountpoint = "/";
        };
        "nix" = {
          zfs_type = "filesystem";
          mountpoint = "/nix";
        };
        "home" = {
          zfs_type = "filesystem";
          mountpoint = "/home";
        };
      };
    };
  };
}
