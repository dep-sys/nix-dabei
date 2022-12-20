{ lib, pkgs, ... }:
{
  # nix-dabei is not tested with other bootloaders,
  # A PR for systemd-boot support would be appreciated.
  boot.loader.grub = {
    enable = true;
    # We use "nodev" here to avoid having to declare the disk device (e.g. /dev/sda) in
    # this config. We let grub only update the menu during (re-)install, while nix-dabei's
    # auto-installer writes the bootloader to MBR.
    device = "nodev";
  };
  # Because ´boot.loader.grub.device = "nodev"´ excludes grub from the system,
  # but we need it inside the target system closure and optimally inside PATH
  # to be able to call it in a chroot during auto-install.
  environment.systemPackages = [ pkgs.grub2 ];

  # Mount zfs datasets created by auto-install from nix-dabei.diskoConfigurations,
  # generating this configuration automatically currently requires disko in your flake;
  # TODO disko: auto-generate config here, or refer to custom example (and do it there)
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
    "/home" =
      {
        device = "rpool/safe/home";
        fsType = "zfs";
      };
  };
}
