{ lib, pkgs, ... }:
{
  boot.loader.grub = {
    enable = true;
    # We use "nodev" here to avoid having to declare the disk device (e.g. /dev/sda) in
    # this config, so we'll only need to know about it during install-time.
    device = "nodev";
  };
  # boot.loader.grub.device = "nodev" excludes grub from the system,
  # but we need it inside the systems close and optimally inside PATH
  # do be able to call it during auto-install.
  environment.systemPackages = [ pkgs.grub2 ];

  fileSystems = {
    "/boot" =
      {
        device = "/dev/disk/by-partlabel/ESP";
        fsType = "vfat";
        neededForBoot = true;
      };
    "/" =
      {
        device = "rpool/local/root";
        fsType = "zfs";
        neededForBoot = true;
      };
    "/nix" =
      {
        device = "rpool/local/nix";
        fsType = "zfs";
        neededForBoot = true;
      };
  };
}
