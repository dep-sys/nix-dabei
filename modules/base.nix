{ config, lib, pkgs, modulesPath, ... }:
with lib;
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  # Disable core stuff which does not have a "enable" flag.
  disabledModules = [
    "system/boot/systemd/logind.nix"
    "system/boot/systemd/coredump.nix"
  ];

  config =
    let
      # default is 100, mkForce is 50
      mkOverride' = mkOverride 60;
    in
      lib.mkMerge [
        {
          nix.extraOptions = "extra-experimental-features = nix-command flakes";

          systemd.package = mkOverride' pkgs.systemdMinimal;
          boot.initrd.systemd = {
            enable = true;
            emergencyAccess = true;
          };
          boot.loader.grub.enable = mkOverride' false;
          environment.noXlibs = mkOverride' true;
        }

        {
          ## Disable Services
          boot.enableContainers = mkOverride' false;
          hardware.enableRedistributableFirmware = mkOverride' false;
          security.polkit.enable = mkOverride' false;
          services.dbus.enable = mkOverride' false;
          services.logrotate.enable = mkOverride' false;
          services.timesyncd.enable = mkOverride' false;
          services.udisks2.enable = mkOverride' false;
          networking.firewall.enable = mkOverride' false;
          services.nscd.enable = mkOverride' false;
        }

        (mkIf (!config.services.nscd.enable) {
          system.nssModules = mkForce [];
        })

        {
          ## Configure kernel and init ramdisk
          boot.initrd.kernelModules = [ "squashfs" "loop" "overlay" ];
          boot.supportedFilesystems = mkOverride' config.boot.initrd.supportedFilesystems;
          boot.kernelParams = [
            "consoleblank=0"
            "console=tty1"
            "console=ttyS0"
            "systemd.show_status=true"
            "systemd.log_level=info"
            "systemd.log_target=console"
            "systemd.journald.forward_to_console=1"
         ];

          # boot.initrd.systemd does not use boot.post*Commands, and so we need to support creating directories
          # for the overlay nix store ourselves.
          #
          #boot.postBootCommands =
          #  ''
          #    # After booting, register the contents of the Nix store
          #    # in the Nix database in the tmpfs.
          #    ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration

          #    # nixos-rebuild also requires a "system" profile and an
          #    # /etc/NIXOS tag.
          #    touch /etc/NIXOS
          #    ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
          #  '';

          systemd.tmpfiles.rules = [
            "f /etc/NIXOS 0644 root root -"
            "d /boot 0644 root root -"
          ];
          boot.initrd.systemd = {
            mounts = [{
              where = "/sysroot/nix/store";
              what = "overlay";
              type = "overlay";
              options = "lowerdir=/sysroot/nix/.ro-store,upperdir=/sysroot/nix/.rw-store/store,workdir=/sysroot/nix/.rw-store/work";
              wantedBy = ["local-fs.target"];
              before = ["local-fs.target"];
              requires = ["sysroot-nix-.ro\\x2dstore.mount" "sysroot-nix-.rw\\x2dstore.mount" "rw-store.service"];
              after = ["sysroot-nix-.ro\\x2dstore.mount" "sysroot-nix-.rw\\x2dstore.mount" "rw-store.service"];
              unitConfig.IgnoreOnIsolate = true;
            }];
            services.rw-store = {
              after = ["sysroot-nix-.rw\\x2dstore.mount"];
              unitConfig.DefaultDependencies = false;
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "/bin/mkdir -p 0755 /sysroot/nix/.rw-store/store /sysroot/nix/.rw-store/work /sysroot/nix/store";
              };
            };
          };
        }

        {
          ## Configure filesystems
          fileSystems."/" =
            {
              fsType = "tmpfs";
              options = [ "mode=0755" ];
              neededForBoot = true;
            };

          fileSystems."/nix/.ro-store" =
            {
              fsType = "squashfs";
              device = "../nix-store.squashfs";
              options = [ "loop" ];
              neededForBoot = true;
            };
          fileSystems."/nix/.rw-store" =
            {
              fsType = "tmpfs";
              options = [ "mode=0755" ];
              neededForBoot = true;
            };
        }];
}
