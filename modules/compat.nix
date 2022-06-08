{ lib, pkgs, ... }:
{
  options = with lib; {
    environment = {
      systemPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        example = literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
        description = ''
          The set of packages that appear in
          /run/current-system/sw.  These packages are
          automatically available to all users, and are
          automatically updated every time you rebuild the system
          configuration.  (The latter is the main difference with
          installing them in the default profile,
          <filename>/nix/var/nix/profiles/default</filename>.
        '';
      };
      pathsToLink = mkOption {
        type = types.listOf types.str;
        # Note: We need `/lib' to be among `pathsToLink' for NSS modules
        # to work.
        default = [];
        example = ["/"];
        description = "List of directories to be symlinked in <filename>/run/current-system/sw</filename>.";
      };
      extraOutputsToInstall = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "doc" "info" "docdev" ];
        description = "List of additional package outputs to be symlinked into <filename>/run/current-system/sw</filename>.";
      };
    };
    system.path = mkOption {
        internal = true;
        description = ''
          The packages you want in the boot environment.
        '';
    };
    boot.isContainer = mkOption {
      # not used for nix-dabei, but needed for evaluation.
      visible = false;
      type = types.bool;
      default = false;
      description = ''
        Whether this NixOS machine is a lightweight container running
        in another NixOS system.
      '';
    };
    boot.initrd.enable = mkOption {
      # not used for nix-dabei, but needed for evaluation.
      visible = false;
      type = types.bool;
      default = true;
      defaultText = literalExpression "!config.boot.isContainer";
      description = ''
        Whether to enable the NixOS initial RAM disk (initrd). This may be
        needed to perform some initialisation tasks (like mounting
        network/encrypted file systems) before continuing the boot process.
      '';
    };
    hardware.firmware = mkOption {
      type = types.listOf types.package;
      default = [];
      description = ''
        List of packages containing firmware files.  Such files
        will be loaded automatically if the kernel asks for them
        (i.e., when it has detected specific hardware that requires
        firmware to function).  If multiple packages contain firmware
        files with the same name, the first package in the list takes
        precedence.  Note that you must rebuild your system if you add
        files to any of these directories.
      '';
      apply = let
        compressFirmware = if config.boot.kernelPackages.kernelAtLeast "5.3"
                           then pkgs.compressFirmwareXz else id;
      in list: pkgs.buildEnv {
        name = "firmware";
        paths = map compressFirmware list;
        pathsToLink = [ "/lib/firmware" ];
        ignoreCollisions = true;
      };
    };
    networking.timeServers = mkOption {
      default = [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
      type = types.listOf types.str;
      description = ''
        The set of NTP servers from which to synchronise.
      '';
    };

    systemd.services = mkOption {
      # dummy to make nixos modules happy
      internal = true;
    };
    systemd.user = mkOption {
      # dummy to make nixos modules happy
      internal = true;
    };

  };

  config = {
    system.activationScripts.users = ''
      # dummy to make setup-etc happy
    '';
    system.activationScripts.groups = ''
      # dummy to make setup-etc happy
    '';

    system.build.earlyMountScript = pkgs.writeScript "dummy" '''';
  };
}
