{ lib, pkgs, ... }:
{
  options = with lib; {
    environment = {
      systemPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        example = literalExample "[ pkgs.firefox pkgs.thunderbird ]";
      };
      pathsToLink = mkOption {
        type = types.listOf types.str;
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
    };
    systemd.services = mkOption {
      # dummy to make nixos modules happy
    };
    systemd.user = mkOption {
      # dummy to make nixos modules happy
    };
    boot.isContainer = mkOption {
      type = types.bool;
      default = false;
    };
    hardware.firmware = mkOption {
      type = types.listOf types.package;
      default = [];
      apply = list: pkgs.buildEnv {
        name = "firmware";
        paths = list;
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
