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

    auto-install.enable = mkOption {
      description = "enable auto installer, see README";
      type = types.bool;
      default = true;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (lib.any (fs: fs == "vfat") config.boot.initrd.supportedFilesystems) {
      boot.initrd.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859-1" ];
    })

    (lib.mkIf cfg.zfs.enable {
      boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
      boot.initrd.supportedFilesystems = [ "zfs" ];
    })

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
      system.stateVersion = lib.trivial.release;

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
          kernelModules = [ "virtio_pci" "virtio_scsi" "ata_piix" "sd_mod" "sr_mod" "ahci" "nvme" ];
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

            extraBin = {
              # nix & installer
              nix = "${pkgs.nixStatic}/bin/nix";
              nix-store = "${pkgs.nixStatic}/bin/nix-store";
              nix-env = "${pkgs.nixStatic}/bin/nix-env";
              busybox = "${pkgs.busybox-sandbox-shell}/bin/busybox";
              nixos-enter = "${pkgs.nixos-install-tools}/bin/nixos-enter";
              unshare = "${pkgs.util-linux}/bin/unshare";

              ssh-keygen = "${config.programs.ssh.package}/bin/ssh-keygen";
              setsid = "${pkgs.util-linux}/bin/setsid";

              # partitioning
              parted = "${pkgs.parted}/bin/parted";

              get-kernel-param = pkgs.writeScript "get-kernel-param" ''
                for o in $(< /proc/cmdline); do
                    case $o in
                        $1=*)
                            echo "''${o#"$1="}"
                            ;;
                    esac
                done
              '';
            };

            # When these are enabled, they prevent useful output from
            # going to the console
            paths.systemd-ask-password-console.enable = false;
            services.systemd-ask-password-console.enable = false;
          };
        };
      };
    }

    (lib.mkIf cfg.ssh.enable {
      boot.initrd = {
        network.ssh = {
          enable = true;
          authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
          port = 22;
        };
        systemd.services = {
          setup-ssh-authorized-keys = {
            requires = ["initrd-fs.target"];
            after = ["initrd-fs.target"];
            requiredBy = [ "sshd.service" ];
            before = [ "sshd.service" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
              mkdir -p /etc/ssh/authorized_keys.d
              param="$(get-kernel-param "ssh_authorized_key")"
              if [ -n "$param" ]; then
                 umask 177
                 (echo -e "\n"; echo "$param" | base64 -d) >> /etc/ssh/authorized_keys.d/root
                 cat /etc/ssh/authorized_keys.d/root
                 echo "Using ssh authorized key from kernel parameter"
              fi
         '';
          };

          generate-ssh-host-key = {
            requires = ["initrd-fs.target"];
            after = ["initrd-fs.target"];
            requiredBy = [ "sshd.service" ];
            before = [ "sshd.service" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
              mkdir -p /etc/ssh/

              param="$(get-kernel-param "ssh_host_key")"
              if [ -n "$param" ]; then
                 umask 177
                 echo "$param" | base64 -d > /etc/ssh/ssh_host_ed25519_key
                 ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
                 echo "Using ssh host key from kernel parameter"
              fi
              if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
                 ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -t ed25519 -N ""
                 echo "Generated new ssh host key"
              fi
          '';
          };
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
              cp -R /bin /etc  /init  /lib  /nix  /root  /sbin  /var /sysroot
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
  ];
}
