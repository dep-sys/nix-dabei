# This file isn't included in the initrd but meant to be
# imported into the deployed instance for some recommended
# defaults and the fileSystem layout.,
{ config, lib, pkg, modulesPath, ... }: {
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {
    services.openssh = {
      enable = true;
      passwordAuthentication = lib.mkForce false;
      permitRootLogin = lib.mkForce "without-password";
    };

    boot = {
      loader.grub = {
        enable = true;
      };
      kernelParams = [
        "ip=dhcp"
      ];
      zfs = {
        forceImportRoot = true; # kernelParms = ["zfs_force=1"];
        # can be a single device, effectively the arg for zpool import -d
        devNodes = "/dev/disk/by-partlabel/zfs";
      };
      initrd = {
        systemd = {
          enable = true;
          emergencyAccess = true;
        };
      };
    };

    fileSystems."/boot" =
      {
        device = "/dev/disk/by-partlabel/ESP";
        fsType = "vfat";
        neededForBoot = true;
      };
    fileSystems."/" =
      {
        device = "rpool/local/root";
        fsType = "zfs";
        neededForBoot = true;
      };
    fileSystems."/nix" =
      {
        device = "rpool/local/nix";
        fsType = "zfs";
        neededForBoot = true;
      };
  };
}
