{ pkgs, config, lib, ... }:
with lib;
{
  config = let
    kernelParams = builtins.unsafeDiscardStringContext (toString config.boot.kernelParams);
    kernelFile = config.system.boot.loader.kernelFile;
    kernel = "${config.system.build.kernel}/${kernelFile}";
    initrd = "${config.system.build.netbootRamdisk}/initrd";
    toplevel = config.system.build.toplevel;
    in {

    system.build.runvm = pkgs.writeShellScript "runner" ''
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name nix-dabei -m 2048 \
        -kernel ${kernel} -initrd ${initrd} -nographic \
        -append "console=ttyS0 init=${toplevel}/init ${kernelParams} " -no-reboot \
        -net nic,model=virtio \
        -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        -device virtio-rng-pci
    '';

    system.build.dist =
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
          kexec --load ''${SCRIPT_DIR}/${kernelFile} \
            --initrd=''${SCRIPT_DIR}/initrd \
            --command-line "init=${toplevel}/init ${kernelParams}"
          if systemctl --version >/dev/null 2>&1; then
            systemctl kexec
          else
            kexec -e
          fi
       '';
      in pkgs.linkFarm "kexec-boot" [
        { name = "initrd"; path = initrd; }
        { name = "bzImage"; path = kernel; }
        { name = "kexec-boot"; path = kexecScript; }
        { name = "command-line"; path = pkgs.writeText "command-line" kernelParams; }
      ];

    system.build.netbootRamdisk = pkgs.makeInitrd {
      inherit (config.boot.initrd) compressor;
      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

      contents =
        [{
          object = config.system.build.squashfsStore;
          symlink = "/nix-store.squashfs";
        }];
    };

    system.build.squashfsStore = pkgs.callPackage "${pkgs.path}/nixos/lib/make-squashfs.nix" {
      storeContents = config.system.build.toplevel;
    };

  };
}
