{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {
    environment.systemPackages = [ ];
    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";
    # TODO: replace this key!
    # It's my personal public key, provided as an example.
    # Nix 2.9 will allow us to use https://github.com/phaer.keys
    # as a flake input instead, but it's not in nixos-stable yet,
    # so we'll continue to support 2.8.
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLopgIL2JS/XtosC8K+qQ1ZwkOe1gFi8w2i1cd13UehWwkxeguU6r26VpcGn8gfh6lVbxf22Z9T2Le8loYAhxANaPghvAOqYQH/PJPRztdimhkj2h7SNjP1/cuwlQYuxr/zEy43j0kK0flieKWirzQwH4kNXWrscHgerHOMVuQtTJ4Ryq4GIIxSg17VVTA89tcywGCL+3Nk4URe5x92fb8T2ZEk8T9p1eSUL+E72m7W7vjExpx1PLHgfSUYIkSGBr8bSWf3O1PW6EuOgwBGidOME4Y7xNgWxSB/vgyHx3/3q5ThH0b8Gb3qsWdN22ZILRAeui2VhtdUZeuf2JYYh8L"
    ];
    services.openssh.enable = true;


    networking = {
      # hostName of the live system, used to quickly identify a running
      # one.
      hostName = "nix-dabei";
      # hostId is required by NixOS ZFS module, to distinquish systems from each other.
      # installed systems should have a unique one, tied to hardware. For a live system such
      # as this, it seems sufficient to use a static one.
      hostId = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);

      # Just an example, you can set your own nameservers or leave them empty if dhcp is used.
      nameservers = [
        # Cloudflare DNS
        "1.1.1.1"
        "1.0.0.1"
        "2606:4700:4700::1111"
        "2606:4700:4700::1001"
      ];

      # This switches from traditional network interface names like "eth0" to predictable ones
      # like enp3s0. While the latter can be harder to predict, it should be stable, while
      # the former might not be.
      usePredictableInterfaceNames = true;
    };

    boot.initrd = {
      # Besides the file systems used for installation of our nixos
      # instances, we might need additional ones for kexec to work.
      # E.g. ext4 for hetzner.cloud, presumably to allow our kexec'ed
      # kernel to load its initrd.
      supportedFilesystems = [
        "vfat" "ext4"
      ];
      # We aim to provide a default set of kernel modules which should
      # support functionality for nixos installers on generic cloud
      # hosts as well as bare metal machines.
      # TODO: Can surely be improved/specialized to save a few bytes.
      # more low-hanging fruit atm, but patches welcome!
      kernelModules = lib.mkForce [
        "squashfs"
        "loop"
        "overlay"
        "virtio_console"
        "virtio_rng"
      ];
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

   # Nix-dabei isn't intended to keep state, but NixOS wants
   # it defined and it does not hurt. You are still able to
   # install any realease with the images built.
   system.stateVersion = "22.05";
  };
}
