{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  # Disable core stuff which does not have a "enable" flag.
  disabledModules = [
      "system/boot/systemd/logind.nix"
      "system/boot/systemd/coredump.nix"
  ];

  config = {
    nix.extraOptions = "extra-experimental-features = nix-command flakes";

    systemd.package = lib.mkForce pkgs.systemdMinimal;
    boot.initrd.systemd = {
      enable = true;
      emergencyAccess = true;
    };

    ## Disable Services

    boot.enableContainers = lib.mkForce false;
    environment.noXlibs = true;
    security.polkit.enable = lib.mkForce false;
    hardware.enableRedistributableFirmware = lib.mkForce false;
    services.dbus.enable = lib.mkForce false;
    services.udisks2.enable = false;
    services.timesyncd.enable = lib.mkForce false;
    services.nscd.enable = lib.mkForce false;
    system.nssModules = lib.mkForce [];

    ## Configure kernel and init ramdisk

    boot.initrd.kernelModules = [ "squashfs" ];
    boot.supportedFilesystems = lib.mkForce config.boot.initrd.supportedFilesystems;
    boot.kernelParams = [ "systemd.log_level=info" "systemd.log_target=console" "systemd.journald.forward_to_console=1" ];

    # boot.initrd.systemd does not use boot.post*Commands, and so we need to support creating directories
    # for the overlay nix store ourselves.
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
    systemd.tmpfiles.rules = [
      "f /etc/NIXOS 0644 root root -"
      "d /boot 0644 root root -"
    ];
  };
}
