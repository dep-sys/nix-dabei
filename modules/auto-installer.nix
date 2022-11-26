{ config, pkgs, lib, ... }:
lib.mkIf config.nix-dabei.auto-install.enable {
  boot.initrd.systemd.services = {
    auto-installer = {
      requires = [ "initrd-fs.target" "systemd-udevd.service" "network-online.target"];
      after = [ "initrd-fs.target" "systemd-udevd.service" "network-online.target"];
      requiredBy = [ "initrd.target" ];
      before = [ "initrd.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      script = ''
          set -euo pipefail

          flake_url="$(get-kernel-param "flake_url")"
          if [ -n "$flake_url" ]
          then
            echo "Using flake url from kernel parameter: $flake_url"
          else
            echo "No flake url defined for auto-installer"
            exit 1
          fi

          udevadm trigger --subsystem-match=block; udevadm settle
          echo "Formatting disk..."
          formatScript="$(nix build --no-link --json "''${flake_url}.config.system.build.formatScript" | jq -r '.[].outputs.out')"
          $formatScript
          echo "Mounting disk..."
          mountScript="$(nix build --no-link --json "''${flake_url}.config.system.build.mountScript" | jq -r '.[].outputs.out')"
          $mountScript

          echo "Installing $flake_url"
          mkdir -p /mnt/{etc,tmp}
          touch /mnt/etc/NIXOS
          nix build  --store /mnt --profile /mnt/nix/var/nix/profiles/system "''${flake_url}.config.system.build.toplevel"
          NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- /run/current-system/bin/switch-to-configuration boot

          set -o errexit
          umount --verbose --recursive /mnt
          echo -e "imported zpool(s) before export"; zpool list
          zpool export -a
          echo -e "imported zpool(s) after export"; zpool list
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
}
