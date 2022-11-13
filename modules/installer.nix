{ config, pkgs, lib, disko, ... }:
let cfg = config.nix-dabei; in
{
  options.nix-dabei = with lib; {
    zfs.enable = mkEnableOption "enable ZFS";
    diskDevice = mkOption {
      description = "disk to NUKE";
      type = types.str;
      default = "/dev/vda";
    };
    diskLayout = mkOption {
      description = "disk layout to install";
      type = types.attrs;
      default = import ../disk-layouts/zfs-simple.nix { inherit (cfg) diskDevice; };
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
      system.stateVersion = "22.11";

      # toplevel does not build without a root fs but is useful for debugging
      # and it does not seem to hurt
      fileSystems."/" =
        {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
          neededForBoot = true;
        };

      boot = {
        loader.grub.enable = false;
        kernelParams = [
          "ip=dhcp"
        ];

        initrd = {
          network = {
            enable = true;
            ssh = {
              enable = true;
              authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
              port = 22;
            };
          };
          # Besides the file systems used for installation of our nixos
          # instances, we might need additional ones for kexec to work.
          # E.g. ext4 for hetzner.cloud, presumably to allow our kexec'ed
          # kernel to load its initrd.
          supportedFilesystems = ["vfat" "ext4"];

       };
      };

      boot.initrd.environment.etc = {
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

      boot.initrd.systemd = {
        enable = true;
        emergencyAccess = true;

        # Network is configured with kernelParams
        network.networks = { };

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
          jq = "${pkgs.jq}/bin/jq";
          tsp-create = pkgs.writeScript "tsp-create" (disko.create cfg.diskLayout);
          tsp-mount = pkgs.writeScript "tsp-mount" (disko.mount cfg.diskLayout);
        };

        # When these are enabled, they prevent useful output from
        # going to the console
        paths.systemd-ask-password-console.enable = false;
        services.systemd-ask-password-console.enable = false;

        services = {
          # Disable switching to stage 2 and cleaning up the initrd
          # to keep sshd running until reboot.
          initrd-switch-root.enable = false;
          initrd-cleanup.enable = false;
          initrd-parse-etc.enable = false;


          generate-ssh-host-key = {
            requires = ["initrd-fs.target"];
            after = ["initrd-fs.target"];
            requiredBy = [ "sshd.service" ];
            before = [ "sshd.service" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
              mkdir -p /etc/ssh/

              for o in $(< /proc/cmdline); do
                  case $o in
                      ssh_host_key=*)
                          IFS== read -r -a param <<< "$o"
                          umask 177
                          echo "''${param[1]}" | base64 -d > /etc/ssh/ssh_host_ed25519_key
                          ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
                          echo "Using ssh host key from kernel parameter"
                          ;;
                  esac
              done
              if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
                 ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -t ed25519 -N ""
                 echo "Generated new ssh host key"
              fi
            '';
          };

          # move everything in / to /sysroot and switch-root into
          # it. This runs a few things twice and wastes some memory
          # but is necessary for nix --store flag as pivot_root does
          # not work on rootfs.
          remount-root = {
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

          get-flake-url = {
            requires = [ "initrd-fs.target"];
            after = [ "initrd-fs.target"];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
                for o in $(< /proc/cmdline); do
                    case $o in
                        flake_url=*)
                            IFS== read -r -a param <<< "$o"
                            flake_url="''${param[1]}"
                            echo $flake_url > /run/flake_url
                            echo "Using flake url from kernel parameter: $flake_url"
                            ;;
                    esac
                done
           '';
          };

          format-disk = {
            requires = [ "systemd-udevd.service" "get-flake-url.service"];
            after = [ "systemd-udevd.service" "get-flake-url.service"];
            requiredBy = [ "install-nixos.service" ];
            before = [ "install-nixos.service" ];
            unitConfig.DefaultDependencies = false;
            unitConfig.ConditionPathExists = "/run/flake_url";
            serviceConfig.Type = "oneshot";
            script = ''
                udevadm trigger --subsystem-match=block; udevadm settle
                sleep 1
                ${disko.create cfg.diskLayout}
                ${disko.mount cfg.diskLayout}
            '';
          };

         install-nixos = {
            requires = ["network-online.target" "get-flake-url.service"];
            after = ["network-online.target" "get-flake-url.service"];
            requiredBy = [ "reboot-after-install.service" ];
            before = [ "reboot-after-install.service" ];
            unitConfig.DefaultDependencies = false;
            unitConfig.ConditionPathExists = "/run/flake_url";
            serviceConfig.Type = "oneshot";
            script = ''
                flake_url="$(cat /run/flake_url)"
                echo "Installing $flake_url"
                mkdir -p /mnt/{etc,tmp}
                touch /mnt/etc/NIXOS
                nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system $flake_url
                NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot
            '';
          };

          reboot-after-install = {
            requires = ["install-nixos.service"];
            after = ["install-nixos.service"];
            requiredBy = [ "initrd.target" ];
            before = [ "initrd.target" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
                set -o errexit
                umount --verbose --recursive /mnt
                zpool export -af
                echo -e "Currently imported zpool(s)"; zpool list
                reboot
            '';
          };

          #shell = {
          #  requiredBy = [ "initrd.target" ];
          #  unitConfig.DefaultDependencies = false;
          #  serviceConfig.Type = "simple";
          #  serviceConfig.Restart = "always";
          #  script = ''
          #    /bin/setsid /bin/sh -c 'exec /bin/sh <> /dev/console >&0 2>&1'
          #  '';
          #};




        };
      };
    }
  ];
}
