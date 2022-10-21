{ config, pkgs, lib, disko, ... }:
let cfg = config.nix-dabei; in
{
  options.nix-dabei = with lib; {
    zfs.enable = mkEnableOption "enable ZFS";
    diskLayout = mkOption {
      description = "disk layout to install";
      type = types.attrs;
      default = import ../disk-layouts/zfs-simple.nix { };
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
      # nix does not build without a root fs
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
              authorizedKeys = [ (lib.readFile ../initrd-network-ssh/id_ed25519.pub) ];
              port = 22;
              hostKeys = [ ../initrd-network-ssh/ssh_host_ed25519_key ];
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
        "resolv.conf".text = "nameserver 1.1.1.1";
        "ssl/certs/ca-certificates.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        "nix/nix.conf".text = ''
        build-users-group =
        extra-experimental-features = nix-command flakes
        # workaround https://github.com/NixOS/nix/issues/5076
        sandbox = false
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

        # TODO shouldn't be needed with nixStatic anymore?
        storePaths = [
          # so nix can look up dns entries
          "${pkgs.glibc}/lib/libnss_dns.so.2"
        ];

        extraBin = {
          # nix & installer
          nix = "${pkgs.nixStatic}/bin/nix";
          nix-store = "${pkgs.nixStatic}/bin/nix-store";
          nix-env = "${pkgs.nixStatic}/bin/nix-env";
          busybox = "${pkgs.busybox-sandbox-shell}/bin/busybox";
          nixos-enter = "${pkgs.nixos-install-tools}/bin/nixos-enter";
          unshare = "${pkgs.util-linux}/bin/unshare";

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
          install-nixos = {
            requires = ["network-online.target"];
            after = ["network-online.target"];
            requiredBy = [ "initrd-switch-root.service" ];
            before = [ "initrd-switch-root.service" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
            cp -R /nix/* /mnt/nix
            mount --bind /mnt/nix /nix
            mkdir -p /mnt/etc
            touch /mnt/etc/NIXOS
            nix build --profile /mnt/nix/var/nix/profiles/system github:dep-sys/nix-dabei#nixosConfigurations.default.config.system.build.toplevel
            NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot
          '';
          };

          format-disk = {
            requires = [ "systemd-udevd.service" "initrd-fs.target"];
            after = [ "systemd-udevd.service"];
            requiredBy = [ "install-nixos.service" ];
            before = [ "install-nixos.service" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig.Type = "oneshot";
            script = ''
            udevadm trigger --subsystem-match=block; udevadm settle
            ${disko.create cfg.diskLayout}
            ${disko.mount cfg.diskLayout}
          '';
          };

          #wait = {
          #  requiredBy = [ "initrd.target" ];
          #  before = [ "initrd.target" ];
          #  unitConfig.DefaultDependencies = false;
          #  serviceConfig.Type = "oneshot";
          #  script = ''
          #    sleep 3600
          #  '';
          #};
        };
      };
    }
  ];
}
