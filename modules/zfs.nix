{ config, pkgs, lib, ... }:
let
  cfg = config.x.storage.zfs;
  efiBoot = config.x.boot.efi;
in
{
  options.x.storage.zfs = {
    datasets = lib.mkOption {
      description = ''
            Datasets to create under the `tank` and `boot` zpools.

            **NOTE:** This option is used only at image creation time, and
            does not attempt to declaratively create or manage datasets
            on an existing system.
          '';

      default = {
        "tank/system/root".mount = "/";
        "tank/system/var".mount = "/var";
        "tank/local/nix".mount = "/nix";
        "tank/user/home".mount = "/home";
      };

      type = with lib; types.attrsOf (types.submodule {
        options = {
          mount = mkOption {
            description = mdDoc "Where to mount this dataset.";
            type = types.nullOr types.string;
            default = null;
          };

          properties = mkOption {
            description = mdDoc "Properties to set on this dataset.";
            type = types.attrsOf types.string;
            default = { };
          };
        };
      });
    };
  };


  config = lib.mkIf (cfg.enable) {
    networking.hostId = lib.mkDefault "00000000";

    fileSystems =
      {
        "/boot" = {
          # The ZFS image uses a partition labeled ESP whether or not we're
          # booting with EFI.
          device = "/dev/disk/by-label/ESP";
          fsType = "vfat";
        };
      }
      //
      (let
        mountable = lib.filterAttrs (_: value: ((value.mount or null) != null)) config.x.storage.zfs.datasets;
      in
        lib.mapAttrs'
          (dataset: opts: lib.nameValuePair opts.mount {
            device = dataset;
            fsType = "zfs";
          })
          mountable);

    boot = {
      zfs.forceImportRoot = false; # kernelParms = ["zfs_force=1"];
      zfs.devNodes = "/dev/";
      growPartition = true;
      kernelParams = [ "elevator=none" ];
      loader = {
        timeout = 1;
        efi.canTouchEfiVariables = lib.mkDefault false;
        grub = {
          copyKernels = true;
          enable = lib.mkDefault true;
          device = if (!efiBoot) then "/dev/vda" else "nodev";
          efiSupport = efiBoot;
          efiInstallAsRemovable = efiBoot;
        };
      };
    };

    services.zfs = {
      expandOnBoot = lib.mkDefault "all";
      trim.enable = true;
      autoScrub.enable = true;
      # zfs set com.sun:auto-snapshot=true $DATASET
      autoSnapshot = {
        enable = true;
        flags = "-k -p --utc";
      };
    };

  };
}
