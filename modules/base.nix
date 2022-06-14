{ pkgs, config, lib, ... }:

with lib;
let cfg = config.nix-dabei;
in
{
  options.nix-dabei = {
  };
  config = {

    system.build.runvm = pkgs.writeScript "runner" ''
      #!${pkgs.stdenv.shell}
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name nix-dabei -m 2048 \
        -kernel ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} -initrd ${config.system.build.netbootRamdisk}/initrd -nographic \
        -append "console=ttyS0 init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} " -no-reboot \
        -net nic,model=virtio \
        -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        -device virtio-rng-pci
    '';

    system.build.dist = pkgs.runCommand "nix-dabei-dist" { } ''
      mkdir $out
      cp ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} $out/${config.system.boot.loader.kernelFile}
      cp ${config.system.build.netbootRamdisk}/initrd $out/initrd
      echo "${builtins.unsafeDiscardStringContext (toString config.boot.kernelParams)}" > $out/command-line
    '';

    system.build.kexecBoot =
      let
        kexecScript = pkgs.writeScript "kexec-boot" ''
          #!/usr/bin/env bash
          TO_INSTALL=""
          command -v kexec || TO_INSTALL="kexec-tools $TO_INSTALL"
          if [ -n "$TO_INSTALL" ]; then
            if [ command -v apt ]; then
              echo "apt found, but no $TO_INSTALL. Installing..."
              apt update -y && DEBIAN_FRONTEND=noninteractive apt install -y $TO_INSTALL
            else
              echo "apt not found, please install: $TO_INSTALL"
              exit 1;
            fi
          fi
          SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
          kexec --load ''${SCRIPT_DIR}/${config.system.boot.loader.kernelFile} \
            --initrd=''${SCRIPT_DIR}/initrd \
            --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
          if systemctl --version >/dev/null 2>&1; then
            systemctl kexec
          else
            kexec -e
          fi
       ''; in
      pkgs.linkFarm "kexec-boot" [
        {
          name = "initrd.gz";
          path = "${config.system.build.netbootRamdisk}/initrd";
        }
        {
          name = "bzImage";
          path = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
        }
        {
          name = "kexec-boot";
          path = kexecScript;
        }
      ];

  };
}
