{
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs {}
}:
let
  inherit (pkgs) lib;


  configure-ssh-key = pkgs.writeShellApplication {
    name = "configure-ssh-key";
    runtimeInputs = [
      pkgs.systemdUkify
      pkgs.mtools
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      set -x
      ssh_key="$1"
      image="nix-dabei.raw"
      encoded_key="$(cat "$ssh_key" | base64 -w0)"

      addon_efi="$(mktemp)"
      trap 'rm -f "$addon_efi"' EXIT

      ukify build \
      --cmdline "systemd.set_credential_binary=ssh.authorized_keys.root:$encoded_key" \
      --output "$addon_efi"

      esp_offset=$(sfdisk -J "$image" | jq '.partitiontable.partitions[0].start * 512')
      spec="''${image}@@''${esp_offset}"
      if ! mdir -i "$spec" ::/EFI/BOOT/BOOTX64.EFI.extra.d/ &>/dev/null; then
        mmd -i "$spec" ::/EFI/BOOT/BOOTX64.EFI.extra.d
      fi
      mcopy -i "$spec" -D o "$addon_efi" ::/EFI/BOOT/BOOTX64.EFI.extra.d/ssh_key.addon.efi
    '';
  };

  shell = pkgs.mkShell {
    name = "nix-dabei";
    packages = [
      pkgs.nix-tree
      configure-ssh-key
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

    openssh = {
      boot.initrd.network.ssh = {
        enable = true;
        ignoreEmptyHostKeys = true;
        authorizedKeys = [ "" ];
      };

      boot.initrd.systemd = {
        contents."/etc/terminfo".source = "${pkgs.ncurses}/share/terminfo";
        contents."/etc/profile".text = ''
          export TERM=linux
          export PS1="$ "
        '';

      # see https://github.com/systemd/systemd/blob/7524671f74c9b0ea858a077ae9b1af3fe574d57e/tmpfiles.d/provision.conf#L19
      # note that we are provisioning to /etc/ssh/authorized_keys.d instead of /root/.ssh/authorized_keys, as roots $HOME
      # is /var/empty in the initrd, so it wouldn't get expanded correctly.
        tmpfiles.settings.root-ssh-keys = {
          "/etc/ssh/authorized_keys.d"."d=" = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/etc/ssh/authorized_keys.d/root"."f^=" = {
            mode = "0600";
            user = "root";
            group = "root";
            argument = "ssh.authorized_keys.root";
          };
        };

        # Generate host keys during boot
        extraBin.ssh-keygen = "${pkgs.openssh}/bin/ssh-keygen";
        services.generate-ssh-hostkeys = {
          description = "Generate SSH host keys";
          wantedBy = [ "sshd.service" ];
          before = [ "sshd.service" ];
          wants = [ "systemd-udevd.service" ];
          after = [ "systemd-udevd.service" ];

          unitConfig = {
            DefaultDependencies = false;
            ConditionPathExists = "!/etc/ssh/ssh_host_ed25519_key";
          };

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key -C "initrd host key"
          echo "Generated initrd SSH host key:"
          ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
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

    zfs = {
      networking.hostId = lib.mkDefault "8425e349";
      boot.initrd.supportedFilesystems.zfs = true;
      boot.zfs.package =
        # https://github.com/nix-community/nixos-images/blob/main/nix/zfs-minimal.nix
        pkgs.zfsUnstable.override {
          samba = pkgs.coreutils;
          python3 = pkgs.python3Minimal;
        };

    };

    image = {config, pkgs, modulesPath, ...}: {
      imports = [ "${modulesPath}/image/repart.nix" ];
      config = {
        image.repart = {
          name = "nix-dabei";
          partitions = {
            esp =
              let
                efiArch = pkgs.stdenv.hostPlatform.efiArch;
                efiUki = "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI";
              in
                {
                  contents = {
                    "${efiUki}".source = "${config.system.build.uki}/nixos.efi";
                  };

                  repartConfig = {
                    Type = "esp";
                    Label = "boot";
                    Format = "vfat";
                    SizeMinBytes = "80M";
                  };
                };
            };
          };
        };
      };
    };

  nixos = pkgs.nixos {
    imports = [
      modules.mini
      modules.no-switch
      modules.vm
      modules.debug
      modules.network
      modules.nix
      modules.openssh
      modules.all-hardware
      modules.zfs
      modules.image
    ];
  };

  inherit (nixos) vm uki image;


in
  {
    inherit shell nixos image vm uki pkgs lib;
  }
