{ lib, pkgs, config, ... }:

with lib;

{
  config = {
    system.build.bootStage2 = pkgs.substituteAll {
      src = pkgs.writeScript "stage2" ''
        #!@shell@

        systemConfig=@systemConfig@
        export PATH=@path@/bin/

        # Print a greeting.
        echo
        echo -e "\e[1;32m<<< Nix-Dabei Stage 2 >>>\e[0m"
        echo

        mkdir -p /proc /sys /dev /tmp /var/log /etc /root /run /nix/var/nix/gcroots
        @earlyMountScript@

        $systemConfig/activate
        ln -sfn "$systemConfig" /run/booted-system

        @postBootCommands

        exec runit
      '';
      isExecutable = true;
      path = config.system.path;
      earlyMountScript = config.system.build.earlyMountScript;
      postBootCommands = config.boot.postBootCommands;
    };
  };
}
