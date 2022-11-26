{ pkgs, config, lib, ... }:
with lib;
{
    config = let
        kernelParams = builtins.unsafeDiscardStringContext (toString config.boot.kernelParams);
        kernelFile = config.system.boot.loader.kernelFile;
        kernel = "${config.system.build.kernel}/${kernelFile}";
        initrd = "${config.system.build.initialRamdisk}/initrd";
        kexec = "${pkgs.pkgsStatic.kexec-tools}/bin/kexec";
        kexecScript = pkgs.writeScript "kexec-boot" ''
          #!/usr/bin/env bash
          SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
          ''${SCRIPT_DIR}/kexec --load ''${SCRIPT_DIR}/${kernelFile} \
            --initrd=''${SCRIPT_DIR}/initrd \
            --command-line "init=/bin/init ${kernelParams} $*"
          if systemctl --version >/dev/null 2>&1; then
            systemctl kexec
          else
            ''${SCRIPT_DIR}/kexec --exec
          fi
       '';
    in {
        system.build.kexec =
            pkgs.linkFarm "kexec" [
                { name = "initrd"; path = initrd; }
                { name = "bzImage"; path = kernel; }
                { name = "kexec-boot"; path = kexecScript; }
                { name = "kexec"; path = kexec; }
            ];
        system.build.installerVM = pkgs.writeShellScriptBin "installer-vm" ''
          test -f disk.img || ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 disk.img 10G
          ssh_host_key="$(cat ${../fixtures/ssh_host_ed25519_key} | base64 -w0)"
          ssh_authorized_key="$(cat ${../fixtures/id_ed25519.pub} | base64 -w0)"
          exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name nix-dabei \
            -m 2048 \
            -kernel ${kernel} -initrd ${initrd} \
            -append "console=ttyS0 init=/bin/init ${kernelParams} ssh_host_key=$ssh_host_key ssh_authorized_key=$ssh_authorized_key flake_url=github:dep-sys/nix-dabei/auto-installer?dir=demo" \
            -no-reboot -nographic \
            -net nic,model=virtio \
            -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
            -drive file=disk.img,format=qcow2,if=virtio \
            -device virtio-rng-pci
        '';
    };
}
