{ lib, pkgs, config, ... }:

with lib;

{
  options = {
    boot = {
      devSize = mkOption {
        default = "5%";
        example = "32m";
        type = types.str;
      };
      devShmSize = mkOption {
        default = "50%";
        example = "256m";
        type = types.str;
      };
      runSize = mkOption {
        default = "25%";
        example = "256m";
        type = types.str;
       };
    };
  };
  config = {
    system.build.bootStage2 = pkgs.substituteAll {
      src = pkgs.writeScript "stage2" ''
      #!@shell@

      systemConfig=@systemConfig@
      export PATH=@path@/bin/

      # Print a greeting.
      echo
      echo -e "\e[1;32m<<< NotOS Stage 2 >>>\e[0m"
      echo

      mkdir -p /proc /sys /dev /tmp /var/log /etc /root /run /nix/var/nix/gcroots
      mount -t proc proc /proc
      mount -t sysfs sys /sys
      mount -t devtmpfs devtmpfs /dev
      mkdir /dev/pts /dev/shm
      mount -t devpts devpts /dev/pts
      mount -t tmpfs tmpfs /run
      mount -t tmpfs tmpfs /dev/shm

      $systemConfig/activate

      exec runit
      '';
      isExecutable = true;
      path = config.system.path;
    };
  };
}
