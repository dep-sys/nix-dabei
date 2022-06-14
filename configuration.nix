{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  disabledModules = [
      "system/boot/systemd/logind.nix"
      "system/boot/systemd/coredump.nix"
  ];

  config = {
    nix-dabei = {
      nix = true;
      simpleStaticIp = true;
    };

    boot.initrd.systemd = {
      enable = true;
      emergencyAccess = true;
    };

    boot.initrd.kernelModules = [ "squashfs" ];
    boot.supportedFilesystems = lib.mkForce config.boot.initrd.supportedFilesystems;
    boot.kernelParams = [ "systemd.log_level=debug" "systemd.log_target=console" "systemd.journald.forward_to_console=1" ];
    systemd.package = lib.mkForce pkgs.systemdMinimal;

    # There's no boot.initrd.postMountCommands with systemd.initrd
    boot.initrd.systemd.services.overlay-helper = {
        after = [  "sysroot-nix-.rw\x2dstore.mount"  "sysroot-nix-.ro\x2dstore.mount" ];
        requiredBy = [ "sysroot-nix-store.mount" ];
        before = [ "sysroot-nix-store.mount" ];
        serviceConfig.Type = "oneshot";
          script = ''mkdir -p /sysroot/nix/.rw-store/store /sysroot/nix/.rw-store/work'';
    };

    #systemd.services.overlay-helper = {
    #    #after = [  "sysroot-nix-.rw\x2dstore.mount"  "sysroot-nix-.ro\x2dstore.mount" ];
    #    requiredBy = [ "initrd-fs.target" ];
    #    serviceConfig.Type = "oneshot";
    #      script = ''mkdir -p /sysroot/nix/.rw-store/store /sysroot/nix/.rw-store/work'';
    #};

    services.openssh.enable = true;

    environment.noXlibs = true;
    security.polkit.enable = lib.mkForce false;
    hardware.enableRedistributableFirmware = lib.mkForce false;
    #services.dbus.enable = lib.mkForce false;
    services.udisks2.enable = false;
    services.timesyncd.enable = lib.mkForce false;

    #system.build.bootStage2 = pkgs.lib.mkForce null;

    networking.hostName = "nix-dabei";
    networking.nameservers = [ "1.1.1.1" ];
    environment.systemPackages = [ ];
    environment.etc = {
      "ssh/authorized_keys.d/root" = {
        text = ''
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLopgIL2JS/XtosC8K+qQ1ZwkOe1gFi8w2i1cd13UehWwkxeguU6r26VpcGn8gfh6lVbxf22Z9T2Le8loYAhxANaPghvAOqYQH/PJPRztdimhkj2h7SNjP1/cuwlQYuxr/zEy43j0kK0flieKWirzQwH4kNXWrscHgerHOMVuQtTJ4Ryq4GIIxSg17VVTA89tcywGCL+3Nk4URe5x92fb8T2ZEk8T9p1eSUL+E72m7W7vjExpx1PLHgfSUYIkSGBr8bSWf3O1PW6EuOgwBGidOME4Y7xNgWxSB/vgyHx3/3q5ThH0b8Gb3qsWdN22ZILRAeui2VhtdUZeuf2JYYh8L
      '';
        mode = "0444";
      };
    };

    system.stateVersion = "22.05";
  };
}
