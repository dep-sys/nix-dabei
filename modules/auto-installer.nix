{ config, pkgs, lib, disko, ... }:
    lib.mkIf config.nix-dabei.auto-install.enable {
  boot.initrd.systemd.services = {
    get-flake-url = {
      requires = [ "initrd-fs.target"];
      after = [ "initrd-fs.target"];
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      script = ''
           param="$(get-kernel-param "flake_url")"
           if [ -n "$param" ]; then
             echo $param > /run/flake_url
             echo "Using flake url from kernel parameter: $param"
           fi
      '';
    };

    #format-disk = {
    #  requires = [ "systemd-udevd.service" "get-flake-url.service"];
    #  after = [ "systemd-udevd.service" "get-flake-url.service"];
    #  requiredBy = [ "install-nixos.service" ];
    #  before = [ "install-nixos.service" ];
    #  unitConfig.DefaultDependencies = false;
    #  unitConfig.ConditionPathExists = "/run/flake_url";
    #  serviceConfig.Type = "oneshot";
    #  script = ''
    #      udevadm trigger --subsystem-match=block; udevadm settle
    #      sleep 1
    #      ${disko.create cfg.diskLayout}
    #      ${disko.mount cfg.diskLayout}
    #  '';
    #};

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
      unitConfig.ConditionPathExists = "/run/flake_url";
      serviceConfig.Type = "oneshot";
      script = ''
          set -o errexit
          umount --recursive /mnt
          zpool export rpool
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
