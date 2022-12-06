{ config, pkgs, lib, disko, diskoConfigurations, ... }:
lib.mkIf config.nix-dabei.auto-install.enable {
  boot.initrd.systemd = {
    extraBin =
      let diskConfig = diskoConfigurations.zfs-simple { disk = "\${disk}"; }; in
      {
        disko-create-zfs-simple = disko.lib.createScriptNoDeps diskConfig pkgs;
        disko-mount-zfs-simple = disko.lib.mountScriptNoDeps diskConfig pkgs;
      };

    services = {
      auto-install = {
        requires = [ "initrd-fs.target" "systemd-udevd.service" "network-online.target"];
        after = [ "initrd-fs.target" "systemd-udevd.service" "network-online.target"];
        requiredBy = [ "initrd.target" ];
        before = [ "initrd.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          set -euo pipefail

          export flake_url="$(get-kernel-param "flake_url")"
          if [ -n "$flake_url" ]
          then
            echo "Using flake url from kernel parameter: $flake_url"
          else
            echo "No flake url defined for auto-install, skipping auto-install"
            exit 0
          fi

          export disks="$(get-kernel-param "disks")"
          if [ -n "disks" ]
          then
            echo "Using disks from kernel parameter: $disks"
          else
            echo "No disks defined for auto-installer"
            exit 1
          fi


          export disk="$disks" # TODO multi-disk support
          udevadm trigger --subsystem-match=block; udevadm settle
          echo "Formatting disk..."
          bash disko-create-zfs-simple
          echo "Mounting disk..."
          bash disko-mount-zfs-simple

          echo "Installing $flake_url"
          mkdir -p /mnt/{etc,tmp}
          touch /mnt/etc/NIXOS
          nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system "''${flake_url}.config.system.build.toplevel"
          NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot

          echo "Unmounting & Reboot"
          umount --verbose --recursive /mnt
          zpool export -a
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
