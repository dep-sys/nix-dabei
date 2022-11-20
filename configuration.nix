{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {
    nix-dabei = {
      zfs.enable = true;
      # disk to NUKE and DELETE ALL DATA. /dev/vda in qemu.
      diskDevice = lib.mkDefault "/dev/vda";
    };
  };
}
