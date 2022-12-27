{ config, pkgs, lib, ... }:
let cfg = config.nix-dabei; in
{
  options.nix-dabei = with lib; {
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
    tty-shell.enable = mkOption {
      description = "enable shell on tty1";
      type = types.bool;
      default = false;
    };

    stay-in-stage-1 = mkOption {
      description = "disable switching to stage-2 so sshd keeps running until reboot";
      type = types.bool;
      default = true;
    };
    remount-root = mkOption {
      description = "remount / on tmpfs to allow pivot_root syscalls";
      type = types.bool;
      default = true;
    };

    ntp = {
      enable = mkOption {
        description = "Enable NTP sync during kexec image startup.";
        type = types.bool;
        default = true;
      };
      update-hardware-clock = mkOption {
        description = ''
          NTPdate only synchronizes the software clock. If 'update-hardware-clock' is
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
        # hostId is required by NixOS ZFS module, to distinquish systems from each other.
        # installed systems should have a unique one, tied to hardware. For a live system such
        # as this, it seems sufficient to use a static one.
        hostId = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);
        # This switches from traditional network interface names like "eth0" to predictable ones
        # like enp3s0. While the latter can be harder to predict, it should be stable, while
        # the former might not be.
        usePredictableInterfaceNames = false;  # for test framework
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
      boot = {
        loader.grub.enable = false;
        kernelParams = [
          "systemd.show_status=true"
          "systemd.log_level=info"
          "systemd.log_target=console"
          "systemd.journald.forward_to_console=1"
        ];

        initrd = {
          kernelModules = [ "virtio_pci" "virtio_scsi" "ata_piix" "sd_mod" "sr_mod" "ahci" "nvme" "e1000e" ];
          network = {
            enable = true;
          };
          # Besides the file systems used for installation of our nixos
          # instances, we might need additional ones for kexec to work.
          # E.g. ext4 for hetzner.cloud, presumably to allow our kexec'ed
          # kernel to load its initrd.
          supportedFilesystems = ["vfat" "ext4"];

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
          };

          systemd = {
            enable = true;
            emergencyAccess = true;

            network.wait-online.anyInterface = true;
            # Network is configured with kernelParams
            network.networks = { };

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
              unshare = "${pkgs.util-linux}/bin/unshare";

              # partitioning
              lsblk = "${pkgs.util-linux}/bin/lsblk";
              findmnt = "${pkgs.util-linux}/bin/findmnt";
              parted = "${pkgs.parted}/bin/parted";
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

    (lib.mkIf cfg.remount-root {
      # move everything in / to /sysroot and switch-root into
      # it. This runs a few things twice and wastes some memory
      # but is necessary for nix --store flag as pivot_root does
      # not work on rootfs.
      boot.initrd.systemd.services.remount-root = {
        requires = [ "systemd-udevd.service" "initrd-root-fs.target"];
        after = [ "systemd-udevd.service"];
        requiredBy = [ "initrd-fs.target" ];
        before = [ "initrd-fs.target" ];

        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          root_fs_type="$(mount|awk '$3 == "/" { print $1 }')"
          if [ "$root_fs_type" != "tmpfs" ]; then
              cp -R /bin /etc  /init /usr /lib  /nix  /root  /sbin  /var /sysroot
              systemctl --no-block switch-root /sysroot /bin/init
          fi
      '';
      };
    })

    (lib.mkIf cfg.stay-in-stage-1 {
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
        services.ntpdate-timesync = let
          ntpServersAsString = lib.concatStringsSep " " cfg.ntp.servers;
        in {
          requires = [ "initrd-fs.target" "network-online.target"];
          requiredBy = [ "auto-installer.service" ];
          before = [ "auto-installer.service" ];
          after = [ "initrd-fs.target" "network-online.target"];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            ntpdate -b ${ntpServersAsString}
            ${lib.optionalString cfg.ntp.update-hardware-clock "hwclock --systohc"}
        '';
        };
      };
    })

    (lib.mkIf cfg.tty-shell.enable {
      boot.initrd.systemd = {
        extraBin = {
              setsid = "${pkgs.util-linux}/bin/setsid";
        };
        services.tty-shell = {
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
  ];
}
