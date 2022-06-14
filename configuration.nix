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
    };

    nix.extraOptions = "extra-experimental-features = nix-command flakes";

    boot.initrd.systemd = {
      enable = true;
      emergencyAccess = true;
    };

    boot.initrd.kernelModules = [ "squashfs" ];
    boot.supportedFilesystems = lib.mkForce config.boot.initrd.supportedFilesystems;
    boot.kernelParams = [ "systemd.log_level=info" "systemd.log_target=console" "systemd.journald.forward_to_console=1" ];
    systemd.package = lib.mkForce pkgs.systemdMinimal;

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


    services.openssh.enable = true;

    environment.noXlibs = true;
    security.polkit.enable = lib.mkForce false;
    hardware.enableRedistributableFirmware = lib.mkForce false;
    #services.dbus.enable = lib.mkForce false;
    services.udisks2.enable = false;
    services.timesyncd.enable = lib.mkForce false;

    services.nscd.enable = lib.mkForce false;
    system.nssModules = lib.mkForce [];


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
