{ lib, pkgs, config, ... }:

with lib;

{
  config = {
    system.build.bootStage2 = pkgs.substituteAll {
      src = pkgs.writeScript "stage2" ''
        #!@shell@

        systemConfig=@systemConfig@
        export PATH=@path@/bin/

        echo
        echo -e "\e[1;32m<<< Nix-Dabei Stage 2 >>>\e[0m"
        echo

        echo -e "\e[1;32m> mounts\e[0m"
        mkdir -p /proc /sys /dev /tmp /var/log /etc /root /run /nix/var/nix/gcroots
        # Mount special file systems.
        specialMount() {
          local device="$1"
          local mountPoint="$2"
          local options="$3"
          local fsType="$4"
          mkdir -m 0755 -p "$mountPoint"
          mount -n -t "$fsType" -o "$options" "$device" "$mountPoint"
        }
        source @earlyMountScript@

        echo -e "\e[1;32m> activation\e[0m"
        $systemConfig/activate
        ln -sfn "$systemConfig" /run/booted-system

        echo -e "\e[1;32m> post-boot\e[0m"
        @postBootCommands@

        echo -e "\e[1;32m> init\e[0m"
        exec runit
      '';
      isExecutable = true;
      path = config.system.path;
      earlyMountScript = config.system.build.earlyMountScript;
      postBootCommands = config.boot.postBootCommands;
    };
  };
}
