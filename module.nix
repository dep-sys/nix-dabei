{ config, pkgs, lib, ... }:
let cfg = config.nixDabei; in
{
  options.nixDabei = with lib; {
    zfs.enable = mkOption {
      description = "enable ZFS";
      type = types.bool;
      default = true;
    };
    ssh.enable = mkOption {
      description = "enable SSHD";
      type = types.bool;
      default = true;
    };
    ttyShell.enable = mkOption {
      description = "enable shell on tty1";
      type = types.bool;
      default = false;
    };

    python.enable = mkOption {
      description = "add a python environment";
      type = types.bool;
      default = true;
    };

    restoreNetwork.enable = mkOption {
      description = "try to restore ips and routes after kexecing";
      type = types.bool;
      default = true;
    };

    stayInStage1 = mkOption {
      description = "disable switching to stage-2 so sshd keeps running until reboot";
      type = types.bool;
      default = true;
    };
    remountRoot = mkOption {
      description = "remount / on tmpfs to allow pivot_root syscalls";
      type = types.bool;
      default = true;
    };

    ntp = {
      enable = mkOption {
        description = "Enable NTP sync during kexec image startup.";
        type = types.bool;
        default = false;
      };
      updateHadwareClock = mkOption {
        description = ''
          NTPdate only synchronizes the software clock. If 'updateHadwareClock' is
          true, the synchronized time will also be written to the hardware clock.
          Disabled per default as it might produce unwanted side-effects on
          virtualized hardware clocks in VMs.
          Enabling this option makes most sense for physical servers with real
          hardware clocks.
        '';
          type = types.bool;
          default = false;
      };
      servers = mkOption {
        description = "NTP server to use for timesync during startup";
        type = types.listOf types.str;
        default = config.networking.timeServers;
      };
    };
  };

  config = lib.mkMerge [
    {
      documentation.enable = false;
      time.timeZone = "UTC";
      i18n.defaultLocale = "en_US.UTF-8";
      networking = {
        hostName = "nix-dabei";
        usePredictableInterfaceNames = false;
        # hostId is required by NixOS ZFS module, to distinquish systems from each other.
        # installed systems should have a unique one, tied to hardware. For a live system such
        # as this, it seems sufficient to use a static one.
        hostId = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);
      };
      # Nix-dabei isn't intended to keep state, but NixOS wants
      # it defined and it does not hurt. You are still able to
      # install any realease with the images built.
      system.stateVersion = "22.11";

      # toplevel does not build without a root fs but is useful for debugging
      # and it does not seem to hurt
      fileSystems."/" =
        {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
          neededForBoot = true;
        };
    }

    {
      environment.etc = {
        "hostname".text = "${config.networking.hostName}\n";
        "resolv.conf".text = "nameserver 1.1.1.1\n"; # TODO replace with systemd-resolved upstream
        "ssl/certs/ca-certificates.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        "nix/nix.conf".text = ''
              build-users-group =
              extra-experimental-features = nix-command flakes
              # workaround https://github.com/NixOS/nix/issues/5076
              sandbox = false

              substituters = https://cache.nixos.org https://nix-dabei.cachix.org
              trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-dabei.cachix.org-1:sDW/xH60rYlBGKzHGFiVvSJpedy+n0CXe6ar3qqUuQk=
            '';
        "group".text = ''
              root:x:0:
              nogroup:x:65534:
            '';
        # Add /etc/os-release + "backport" system.nixos.variant_id to get recognized as an installer
        # by nixos-remote
        "os-release".text = config.environment.etc.os-release.text + "\nVARIANT_ID=\"installer\"";
      };

      systemd = {
        network.wait-online.anyInterface = true;
        # Network is configured with kernelParams
        network.networks = { };

      };

      boot = {
        loader.grub.enable = false;
        kernelParams = [
          "systemd.show_status=true"
          "systemd.log_level=info"
          "systemd.log_target=console"
          "systemd.journald.forward_to_console=1"
          "console=tty0"
          "console=ttyS0,115200"
        ] ++
        (lib.optional (pkgs.stdenv.hostPlatform.isAarch32 || pkgs.stdenv.hostPlatform.isAarch64) "console=ttyAMA0,115200") ++
        (lib.optional (pkgs.stdenv.hostPlatform.isRiscV) "console=ttySIF0,115200");

        initrd = {
          kernelModules = [
            "loop" "overlay" "dm_mod" "squashfs"
            # Intel network for some hetzner dedicated hosts
            "e1000e"
            # copied from https://github.com/nix-community/nixos-images kexec installer.
            "ahci" "ata_piix"
            "sata_inic162x" "sata_nv" "sata_promise" "sata_qstor" "sata_sil" "sata_sil24" "sata_sis" "sata_svw" "sata_sx4" "sata_uli" "sata_via" "sata_vsc"
            "pata_ali" "pata_amd" "pata_artop" "pata_atiixp" "pata_efar" "pata_hpt366" "pata_hpt37x" "pata_hpt3x2n" "pata_hpt3x3" "pata_it8213" "pata_it821x"
            "pata_jmicron" "pata_marvell" "pata_mpiix" "pata_netcell" "pata_ns87410" "pata_oldpiix" "pata_pcmcia" "pata_pdc2027x" "pata_qdi" "pata_rz1000"
            "pata_serverworks" "pata_sil680" "pata_sis" "pata_sl82c105" "pata_triflex" "pata_via" "pata_winbond"
            "3w-9xxx" "3w-xxxx" "aic79xx" "aic7xxx" "arcmsr" "hpsa" "uas" "sdhci_pci" "nvme" "ohci1394" "sbp2"
            "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "virtio_balloon" "virtio_console"
            "mptspi" "vmxnet3" "vsock" "vmw_balloon" "vmw_vmci" "vmwgfx" "vmw_vsock_vmci_transport" "hv_storvsc"
            "md_mod" "raid0" "raid1" "raid10" "raid456"
            "ext2" "ext4"
            "sd_mod" "sr_mod" "mmc_block" "uhci_hcd" "ehci_hcd" "ehci_pci" "ohci_hcd" "ohci_pci" "xhci_hcd" "xhci_pci"
            "usbhid" "hid_generic" "hid_lenovo" "hid_apple" "hid_roccat" "hid_logitech_hidpp" "hid_logitech_dj" "hid_microsoft" "hid_cherry" "pcips2" "atkbd"
            "i8042" "rtc_cmos"
            "bridge" "macvlan" "tap" "tun"
          ];
          network = {
            enable = true;
          };
          # Besides the file systems used for installation of our nixos
          # instances, we might need additional ones for kexec to work.
          # E.g. ext4 for hetzner.cloud, presumably to allow our kexec'ed
          # kernel to load its initrd.
          supportedFilesystems = ["vfat" "ext4"];

          systemd = {
            enable = true;
            emergencyAccess = true;

            # This is the upstream expression, just with bashInteractive instead of bash.
            initrdBin = let
              systemd = config.boot.initrd.systemd.package;
            in lib.mkForce ([pkgs.bashInteractive pkgs.coreutils systemd.kmod systemd] ++ config.system.fsPackages);

            storePaths = [
              "${pkgs.ncurses}/share/terminfo/"
              "${pkgs.bash}"
            ];

            contents."/usr/bin/env".source = "${pkgs.coreutils}/bin/env";
            extraBin = {
              # nix & installer
              nix = "${pkgs.nixStatic}/bin/nix";
              nix-store = "${pkgs.nixStatic}/bin/nix-store";
              nix-env = "${pkgs.nixStatic}/bin/nix-env";
              busybox = "${pkgs.busybox-sandbox-shell}/bin/busybox";
              nixos-enter = "${pkgs.nixos-install-tools}/bin/nixos-enter";
              nixos-install = "${pkgs.nixos-install-tools}/bin/nixos-install";
              unshare = "${pkgs.util-linux}/bin/unshare";

              ip = "${pkgs.iproute2}/bin/ip";
              rsync = "${pkgs.rsync}/bin/rsync";
              # partitioning
              lsblk = "${pkgs.util-linux}/bin/lsblk";
              findmnt = "${pkgs.util-linux}/bin/findmnt";
              parted = "${pkgs.parted}/bin/parted";
              jq = "${pkgs.jq}/bin/jq";
           };

            # When these are enabled, they prevent useful output from
            # going to the console
            paths.systemd-ask-password-console.enable = false;
            services.systemd-ask-password-console.enable = false;
          };
        };
      };
    }

    (lib.mkIf (lib.any (fs: fs == "vfat") config.boot.initrd.supportedFilesystems) {
      boot.initrd.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];
    })

    (lib.mkIf cfg.zfs.enable {
      boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
      boot.initrd.supportedFilesystems = [ "zfs" ];
    })

    (lib.mkIf cfg.ssh.enable {
      boot.initrd = {
        network.ssh = {
          enable = true;
          authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
          port = 22;
        };
      };
    })

    (lib.mkIf cfg.remountRoot {
      # move everything in / to /sysroot and switch-root into
      # it. This runs a few things twice and wastes some memory
      # but is necessary for nix --store flag as pivot_root does
      # not work on rootfs.
      boot.initrd.systemd.services.remountRoot = {
        requires = [ "systemd-udevd.service" "initrd-root-fs.target"];
        after = [ "systemd-udevd.service"];
        requiredBy = [ "initrd-fs.target" ];
        before = [ "initrd-fs.target" ];

        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /var
          root_fs_type="$(mount|awk '$3 == "/" { print $1 }')"
          if [ "$root_fs_type" != "tmpfs" ]; then
              cp -R /init /bin /etc /usr /lib /nix /root  /sbin  /var /sysroot
              mkdir -p /sysroot/tmp
              systemctl --no-block switch-root /sysroot /bin/init
          fi
      '';
      };
    })

    (lib.mkIf cfg.stayInStage1 {
      boot.initrd.systemd.services = {
        initrd-switch-root.enable = false;
        initrd-cleanup.enable = false;
        initrd-parse-etc.enable = false;
      };
    })


    # Synchronize time using NTP to prevent clock skew that could interfere
    # with date & time sensitive operations like certificate verification.
    (lib.mkIf cfg.ntp.enable {
      boot.initrd.systemd = {
        extraBin = {
          hwclock = "${pkgs.util-linux}/bin/hwclock";
          ntpdate = "${pkgs.ntp}/bin/ntpdate";
        };
        services.ntp = let
          ntpServersAsString = lib.concatStringsSep " " cfg.ntp.servers;
        in {
          requires = [ "initrd-fs.target" "network-online.target"];
          requiredBy = [ "initrd.target" ];
          after = [ "initrd-fs.target" "network-online.target"];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            ntpdate -b ${ntpServersAsString}
            ${lib.optionalString cfg.ntp.updateHadwareClock "hwclock --systohc"}
        '';
        };
      };
    })

    (lib.mkIf cfg.ttyShell.enable {
      boot.initrd.systemd = {
        extraBin = {
              setsid = "${pkgs.util-linux}/bin/setsid";
        };
        services.ttyShell = {
          requiredBy = [ "initrd.target" ];
          conflicts = [ "shutdown.target" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "simple";
          serviceConfig.Restart = "always";
          script = ''
          /bin/setsid /bin/sh -c 'exec ${pkgs.bashInteractive}/bin/bash <> /dev/console >&0 2>&1'
        '';
        };
      };
    })
    (lib.mkIf cfg.python.enable {
      boot.initrd.systemd =
        let
          python = pkgs.python3Minimal; #.withPackages (p: [ p.requests ]);
        in {
        storePaths = [
          python
        ];
        extraBin = {
              python = "${python}/bin/python";
        };
      };
    })

    (lib.mkIf cfg.restoreNetwork.enable {
      boot.initrd.systemd =
        let
          python3MinimalWriter = pkgs.writers.makePythonWriter pkgs.python3Minimal pkgs.python3Minimal.pkgs pkgs.python3Minimal.pkgs;
          restoreNetworkScript = python3MinimalWriter "restore_network" {
            flakeIgnore = ["E501"];
          } ./restore_routes.py;
        in {
          storePaths = [
            restoreNetworkScript
          ];
          services.restoreNetwork = {
            requires = [ "initrd-fs.target" ];
            after= [ "initrd-fs.target" ];
            requiredBy = [ "initrd.target" ];
            before = [ "initrd.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = [
                "${restoreNetworkScript} /root/network/addrs.json /root/network/routes-v4.json /root/network/routes-v6.json /etc/systemd/network"
                "/bin/bash -c 'ls /etc/systemd/network'"
                "/bin/bash -c 'cat /etc/systemd/network/eth0.network'"
                "/bin/bash -c 'cat /etc/systemd/network/eth1.network'"
                "/bin/bash -c 'ls -R /etc/ssh'"
                "/bin/bash -c 'cat /etc/ssh/authorized_keys.d/root'"
             ];
            };
            unitConfig.DefaultDependencies = false;
            unitConfig.ConditionPathExists = [
              "/root/network/addrs.json"
              "/root/network/routes-v4.json"
              "/root/network/routes-v6.json"
            ];
          };
      };
    })


  ];
}
