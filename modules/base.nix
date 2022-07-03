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
          environment.noXlibs = mkOverride' true;

          systemd.package = mkOverride' pkgs.systemdMinimal;
          systemd.shutdownRamfs.enable = mkOverride' false;
          systemd.tmpfiles.rules = [
            "f /etc/NIXOS 0644 root root -"
            "d /boot 0644 root root -"
          ];

          boot.loader.grub.enable = mkOverride' false;
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

          fileSystems = {
            "/" =
              {
                fsType = "tmpfs";
                options = [ "mode=0755" ];
                neededForBoot = true;
              };
            "/nix/.ro-store" =
              {
                fsType = "squashfs";
                device = "../nix-store.squashfs";
                options = [ "loop" ];
                neededForBoot = true;
              };
            "/nix/.rw-store" =
              {
                fsType = "tmpfs";
                options = [ "mode=0755" ];
                neededForBoot = true;
              };
          };
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
      ];
}
