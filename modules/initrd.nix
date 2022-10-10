{ lib, config, ... }: {
  ## Configure kernel and init ramdisk
  ##
  boot.initrd = {
    # Besides the file systems used for installation of our nixos
    # instances, we might need additional ones for kexec to work.
    # E.g. ext4 for hetzner.cloud, presumably to allow our kexec'ed
    # kernel to load its initrd.
    supportedFilesystems = [
      "vfat" "ext4"
    ]
    ++ lib.optionals config.nix-dabei.zfs.enable [ "zfs" ];
    # We aim to provide a default set of kernel modules which should
    # support functionality for nixos installers on generic cloud
    # hosts as well as bare metal machines.
    # TODO: Can surely be improved/specialized to save a few bytes.
    # more low-hanging fruit atm, but patches welcome!
    #kernelModules = lib.mkOverride 60 [
    #  "squashfs"
    #  "loop"
    #  "overlay"
    #  "virtio_console"
    #  "virtio_rng"
    #];
    availableKernelModules = [
      "virtio_net"
      "virtio_blk"
      "virtio_pci"
      "virtio_scsi"
      "ata_piix" # Intel PATA/SATA controllers
      "xhci_pci" # USB Extensible Host Controller Interface
      "sd_mod"  # SCSI disk support
      "sr_mod"  # SCSI cdrom support
    ];
  };

  boot.initrd.systemd = {
    enable = true;
    emergencyAccess = true;

    # boot.initrd.systemd does not use boot.post*Commands, and so we need to support creating directories
    # for the overlay nix store ourselves.
    #
    # TODO check if the following commands are needed or if the nix store works as expected
    #boot.postBootCommands =
    #  ''
    #    # After booting, register the contents of the Nix store
    #    # in the Nix database in the tmpfs.
    #    ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration

    #    # nixos-rebuild also requires a "system" profile and an
    #    # /etc/NIXOS tag.
    #    touch /etc/NIXOS
    #    ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    #  '';
    mounts = [{
      where = "/sysroot/nix/store";
      what = "overlay";
      type = "overlay";
      options = "lowerdir=/sysroot/nix/.ro-store,upperdir=/sysroot/nix/.rw-store/store,workdir=/sysroot/nix/.rw-store/work";
      wantedBy = ["local-fs.target"];
      before = ["local-fs.target"];
      requires = ["sysroot-nix-.ro\\x2dstore.mount" "sysroot-nix-.rw\\x2dstore.mount" "rw-store.service"];
      after = ["sysroot-nix-.ro\\x2dstore.mount" "sysroot-nix-.rw\\x2dstore.mount" "rw-store.service"];
      unitConfig.IgnoreOnIsolate = true;
    }];
    services.rw-store = {
      after = ["sysroot-nix-.rw\\x2dstore.mount"];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/bin/mkdir -p 0755 /sysroot/nix/.rw-store/store /sysroot/nix/.rw-store/work /sysroot/nix/store";
      };
    };
  };
}
