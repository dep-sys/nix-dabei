{ disks, ... }:
let
  disk = builtins.head disks;
in {
  disk = {
    ${disk} = {
      device = disk;
      type = "disk";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            name = "boot";
            type = "partition";
            start = "0%";
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
        acltype = "posixacl";
        atime = "off";
        mountpoint = "none";
        canmount = "off";
        xattr = "sa";
      };
      datasets = let
        unmountable = {
          zfs_type = "filesystem";
          mountpoint = null;
          options.canmount = "off";
        };
        filesystem = mountpoint: {
          zfs_type = "filesystem";
          inherit mountpoint;
        };
      in {
        "local" = unmountable;
        "safe" = unmountable;
        "local/root" = filesystem "/" // { options.mountpoint = "legacy"; };
        "local/nix" = filesystem "/nix"  // { options.mountpoint = "legacy"; };
        "safe/home" = filesystem "/home";
      };
    };
  };
}
