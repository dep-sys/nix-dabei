{ config, pkgs, lib, disko, diskoConfigurations, ... }:
lib.mkIf config.nix-dabei.auto-install.enable {
  boot.initrd.systemd = {
    extraBin =
      let
        args = { inherit lib; disks = [ "\${disk1}" "\${disk2}" ]; };
        zfs-simple = diskoConfigurations.zfs-simple args;
        zfs-mirror = diskoConfigurations.zfs-mirror args;
      in
      {
        disko-create-zfs-simple = disko.lib.createScriptNoDeps zfs-simple pkgs;
        disko-mount-zfs-simple = disko.lib.mountScriptNoDeps zfs-simple pkgs;
        disko-create-zfs-mirror = disko.lib.createScriptNoDeps zfs-mirror pkgs;
        disko-mount-zfs-mirror = disko.lib.mountScriptNoDeps zfs-mirror pkgs;
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

          udevadm trigger --subsystem-match=block; udevadm settle

          disks_raw="$(get-kernel-param "disks")"
          disks_layout="''${disks_raw%%:*}"
          disks_string="''${disks_raw##*:}"
          declare -a disks
          IFS="," read -a disks <<< $disks_string
          disks_num=''${#disks[@]}

          if [ $disks_num -eq 0 ]; then
            echo "No disks defined for auto-installer"
            exit 1
          elif [ $disks_num -ge 1 ]; then
              for i in ''${!disks[@]}; do
                  export "disk$((i+1))"="''${disks[i]}";
              done
              echo "disk1=''${disk1:-} disk2=''${disk2:-}"
              echo "Formatting ''${disks_num} disks with layout ''${disks_layout}: ''${disks[*]}"

              if [ "$disks_layout" = "zfs-single" ]; then
                 bash disko-create-zfs-simple
                 echo "Mounting disk..."
                 bash disko-mount-zfs-simple
              elif [ "$disks_layout" = "zfs-mirror" ]; then
                 bash disko-create-zfs-mirror
                 echo "Mounting disk..."
                 bash disko-mount-zfs-mirror
              else
                 echo "Wrong layout or number of disks: ''${disks_raw}".
                 exit 1
              fi

          else
            echo "Unsupported disk options"
            exit 1
          fi


          echo "Installing $flake_url"
          mkdir -p /mnt/{etc,tmp}
          touch /mnt/etc/NIXOS

          echo "Installing system closure..."
          nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system "''${flake_url}.config.system.build.toplevel"

          echo "Installing grub..."
          # TODO read $disks from files or so, in order to be able to split the installer into phases again.
          # ( can't depend on "global" shell vars )
          # TODOL: uefi support: don't install grub at all, depend well-known path?
          for disk in ''${disks[@]}; do
              nixos-enter --root /mnt -- /run/current-system/sw/sbin/grub-install $disk
          done

          echo "Switching to configuration..."
          NIXOS_INSTALL_BOOTLOADER=0 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot

          echo "Unmounting & Reboot"
          umount --verbose --recursive /mnt
          zpool export -a
          reboot
      '';
      };
    };
  };
}
