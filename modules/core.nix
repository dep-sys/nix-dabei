{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  options.x = {
    admins = lib.mkOption {
      description = lib.mdDoc "Attrset of admin username and ssh keys";
      type = lib.types.attrsOf (lib.types.listOf lib.types.string);
      default = {};
    };

    boot.efi = lib.mkOption {
      description = lib.mdDoc "Whether the target system boots via EFI or legacy boot.";
      type = lib.types.bool;
      default = false;
    };

    storage.image.format = lib.mkOption {
      description = lib.mdDoc ''
        format of the disk image to build.
        Use "qcow2-compressed" to optimize for transferred bandwidth if qemu-img is available remotely,
        or use "raw" to `ssh $HOST "cat > /dev/vda"` directly if disk space in live system is thight.
      '';
      type = lib.types.enum ["qcow2" "qcow2-compressed" "vdi" "vpc" "raw"];
      default = "qcow2-compressed";
    };
  };

  config = {
    assertions = [
      {
        assertion = !config.x.boot.efi;
        message = "EFI support is planned, but not implemented yet.";
      }
      {
        assertion = config.x.storage.zfs.enable;
        message = "We are open to other file systems, but atm only ZFS is supported.";
      }
    ];


    # Let 'nixos-version --json' know about the Git revision of this flake.
    system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;
    system.stateVersion = lib.mkDefault "22.05";

    users = {
      mutableUsers = lib.mkDefault false;
      users =
        {
          root = {
            isSystemUser = true;
            openssh.authorizedKeys.keys = lib.flatten (lib.attrValues config.x.admins);
          };
        }
        // (
          lib.mapAttrs (name: keys: {
            isNormalUser = true;
            extraGroups = ["wheel"];
            openssh.authorizedKeys.keys = keys;
          })
          config.x.admins
        );
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    time.timeZone = lib.mkDefault "UTC";
    boot.cleanTmpDir = lib.mkDefault true;

    services.openssh = {
      enable = lib.mkDefault true;
      passwordAuthentication = lib.mkDefault false;
      permitRootLogin = lib.mkDefault "without-password";
      authorizedKeysFiles = [ "/boot/%u.pub" ];
    };
    # Allow building a system without passwords or pub keys, as we might get our ssh keys
    # only during runtime from /boot.
    users.allowNoPasswordLogin = true;

    # Network configuration.
    networking.useDHCP = lib.mkDefault true;
    networking.firewall.allowedTCPPorts = [22];

    # Shell environment
    security.sudo = {
      enable = lib.mkDefault true;
      wheelNeedsPassword = lib.mkDefault false;
    };

    # Kernel parameters for debugging
    boot.kernelParams = [
      "boot.panic_on_fail"
      "stage1panic"
      "consoleblank=0"
      "systemd.show_status=true"
      "systemd.log_level=info"
      "systemd.log_target=console"
      "systemd.journald.forward_to_console=1"
      "console=tty1"
    ];
  };
}
