{
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs {}
}:
let
  inherit (pkgs) lib;

  shell = pkgs.mkShell {
    name = "nix-dabei";
    packages = [
      pkgs.nix-tree
    ];
  };

  modules = {
    mini = {
      boot.loader.grub.enable = false;
      boot.initrd.systemd.enable = true;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      system.stateVersion = "25.11";
    };

    no-switch = {
      boot.initrd.systemd = {
        targets.initrd-switch-root.enable = true;
        services.initrd-switch-root.enable = true;
        services.initrd-cleanup.enable = true;
        services.initrd-parse-etc.enable = false;
        services.initrd-nixos-activation.enable = false;
        services.initrd-find-nixos-closure.enable = false;
      };
    };

    vm = {
      virtualisation.vmVariant.virtualisation = {
        cores = 8;
        memorySize = 1024 * 8;
        graphics = false;
        fileSystems = lib.mkForce {};
        diskImage = lib.mkForce null;
      };
    };

    debug = {
      boot.kernelParams = [
        "rd.systemd.debug_shell=ttyS0"
      ];

      boot.initrd.systemd = {
        emergencyAccess = true;

        initrdBin = [
          pkgs.gnugrep
          pkgs.gawk
          pkgs.helix
          pkgs.rsync
        ];

        services."switch-to-tmpfs" = {
          description = "Copy initrd to tmpfs sysroot";
          after = [ "sysroot.mount" ];
          before = [ "initrd-switch-root.target" ];
          requiredBy = [ "initrd-switch-root.target" ];
          wantedBy = [ "initrd.target" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            rsync -avz / /sysroot/ --exclude=/sysroot -x
          '';
        };
      };
    };

    network = {
      boot.initrd.systemd = {
        initrdBin = [
          pkgs.iputils
          pkgs.iproute2
        ];
        network = {
          enable = true;
          networks."10-default" = {
            enable = true;
            matchConfig.Name = "en*";
            DHCP = "yes";
          };
        };
        # remove initrd-switch-root.target conflict
        services.systemd-resolved.unitConfig.Conflicts = [ "" ];
        services.systemd-networkd.unitConfig.Conflicts = [ "" ];
        contents = let
          caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        in {
          "/etc/ssl/certs/ca-bundle.crt".source = caBundle;
          "/etc/ssl/certs/ca-certificates.crt".source = caBundle;
        };
      };
    };

    nix = {config, ...}: let
      bldUsers = lib.map (n: "nixbld${toString n}") (lib.range 1 10);
    in {
      boot.initrd.systemd = {
        users = lib.genAttrs
          bldUsers
          (n: {group = "nixbld"; });
        groups.nixbld = { };
        initrdBin = [ pkgs.nixStatic ];
        contents."/etc/group".text =
          lib.mkForce ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (n: { gid }: "${n}:x:${toString gid}:${lib.optionalString (n == "nixbld") (lib.concatStringsSep "," bldUsers)}") config.boot.initrd.systemd.groups
            )}
          '';

        contents."/etc/nix/nix.conf".text = ''
          experimental-features = nix-command flakes auto-allocate-uids
        '';
      };
    };
  };
    all-hardware = {
      hardware.enableRedistributableFirmware = true;

      boot.initrd.availableKernelModules = [
        # NVMe & SATA/AHCI
        "nvme" "ahci" "sd_mod" "sr_mod"

        # USB Storage
        "usb_storage" "uas"

        # MMC/SD Cards
        "mmc_core" "mmc_block" "sdhci" "sdhci_pci" "sdhci_acpi"

        # Virtualization storage
        "virtio_blk" "virtio_scsi" "hv_storvsc" "vmw_pvscsi"

        # RAID & Device Mapper
        "dm_mod" "dm_crypt" "dm_snapshot" "dm_thin_pool"
        "md_mod" "raid0" "raid1" "raid10" "raid456"

        # Other storage
        "loop" "nbd"

        # Filesystems
        "ext4" "btrfs" "xfs" "f2fs" "vfat" "ntfs3"
        "squashfs" "overlay" "iso9660"
        "nfs" "cifs" "fuse"

        # USB host controllers
        "xhci_hcd" "ehci_hcd" "ohci_hcd"

        # Input
        "usbhid" "hid_generic" "evdev"

        # Intel Ethernet
        "e1000" "e1000e" "igb" "igc" "ixgbe" "ixgbevf" "i40e" "ice"

        # Realtek Ethernet
        "r8169"

        # Broadcom Ethernet
        "tg3" "bnx2" "bnx2x"

        # Other Ethernet
        "alx" "atl1c" "sky2" "skge" "forcedeth"

        # Virtualization network
        "virtio_pci" "virtio_net" "hv_netvsc" "vmxnet3"

        # Graphics (basic display)
        # "i915" "amdgpu" "nouveau" "fbcon" "vesafb" "efifb"

        # Intel Wireless
        # "iwlwifi" "iwlmvm"

        # Realtek Wireless
        # "rtw88_pci" "rtw89_pci" "rtl8xxxu"

        # Atheros/Qualcomm Wireless
        # "ath9k" "ath10k_pci" "ath11k_pci" "ath12k"

        # Broadcom Wireless
        # "brcmfmac" "brcmsmac"

        # MediaTek Wireless
        # "mt7921e" "mt76x2e" "mt7915e"

      ];
    };

  nixos = pkgs.nixos {
    imports = [
      modules.mini
      modules.no-switch
      modules.vm
      modules.debug
      modules.network
      modules.nix
      modules.all-hardware
    ];
  };

  inherit (nixos) vm;

in
 {
   inherit shell nixos vm pkgs lib;
 }
