{ pkgs, config, lib, ... }:
with lib;
{
    config = let
        kernelParams = builtins.unsafeDiscardStringContext (toString config.boot.kernelParams);
        kernelFile = config.system.boot.loader.kernelFile;
        kernel = "${config.system.build.kernel}/${kernelFile}";
        initrd = "${config.system.build.initialRamdisk}/initrd";
        kexec = "${pkgs.pkgsStatic.kexec-tools}/bin/kexec";
        iprouteStatic = pkgs.pkgsStatic.iproute2.override { iptables = null; };
        iproute = "${iprouteStatic}/bin/ip";
        kexecScript = pkgs.writeScript "kexec-boot" ''
          #!/usr/bin/env bash
          SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

          # INITRD_TMP / extra.gz logic taken from https://github.com/nix-community/nixos-images/blob/main/nix/kexec-installer/module.nix
          INITRD_TMP=$(TMPDIR=$SCRIPT_DIR mktemp -d)
          cd "$INITRD_TMP"
          pwd
          mkdir -p initrd/etc/ssh/authorized_keys.d
          pushd initrd
          for key in /root/.ssh/authorized_keys /root/.ssh/authorized_keys2; do
            if [ -e "$key" ]; then
              # workaround for debian shenanigans
              grep -o '\(ssh-[^ ]* .*\)' "$key" >> etc/ssh/authorized_keys.d/root
            fi
          done
          # Typically for NixOS
          if [ -e /etc/ssh/authorized_keys.d/root ]; then
            cat /etc/ssh/authorized_keys.d/root >> etc/ssh/authorized_keys.d/root
          fi
          for p in /etc/ssh/ssh_host_*; do
            cp -a "$p" etc/ssh/
          done

          if type -p ip &>/dev/null; then
            mkdir -p root/network
            pushd root/network
            echo "Saving networking configuration for later use."
            "$SCRIPT_DIR/ip" --json addr > addrs.json
            "$SCRIPT_DIR/ip" -4 --json route > routes-v4.json
            "$SCRIPT_DIR/ip" -6 --json route > routes-v6.json
            popd
          else
            echo "Skip saving static network addresses because no iproute2 binary is available." 2>&1
            echo "The image can depends only on DHCP to get network after reboot!" 2>&1
          fi
          find | cpio -o -H newc | gzip -9 > ../extra.gz
          popd
          cat extra.gz >> "''${SCRIPT_DIR}/initrd"
          rm -r "$INITRD_TMP"

          ''${SCRIPT_DIR}/kexec --load ''${SCRIPT_DIR}/${kernelFile} \
            --kexec-syscall-auto \
            --initrd=''${SCRIPT_DIR}/initrd \
            --command-line "init=/bin/init ${kernelParams} $*"

          # Disconnect our background kexec from the terminal
          echo "machine will boot into nixos in in 6s..."
          if [[ -e /dev/kmsg ]]; then
            # this makes logging visible in `dmesg`, or the system consol or tools like journald
            exec > /dev/kmsg 2>&1
          else
            exec > /dev/null 2>&1
          fi

          # We will kexec in background so we can cleanly finish the script before the hosts go down.
          # This makes integration with tools like terraform easier.
          nohup bash -c "sleep 6; if systemctl --version >/dev/null 2>&1; then systemctl kexec; else ''${SCRIPT_DIR}/kexec --exec; fi" &
       '';
    in {
        system.build.kexec =
            pkgs.linkFarm "kexec" [
                { name = "initrd"; path = initrd; }
                { name = "bzImage"; path = kernel; }
                { name = "run"; path = kexecScript; }
                { name = "kexec"; path = kexec; }
                { name = "ip"; path = "${iprouteStatic}/bin/ip"; }
            ];

        system.build.kexecTarball = pkgs.runCommand "kexec-tarball" {} ''
          mkdir kexec $out
          cp "${initrd}" kexec/initrd
          cp "${kernel}" kexec/bzImage
          cp "${kexecScript}" kexec/run
          cp "${kexec}" kexec/kexec
          cp "${iproute}" kexec/ip
          tar -czvf $out/nixos-kexec-installer-${pkgs.stdenv.hostPlatform.system}.tar.gz kexec
        '';

        system.build.vm = pkgs.writeShellScriptBin "installer-vm" ''
          set -euo pipefail
          test -f disk.img || ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 disk.img 10G

          TMP_INITRD=$(mktemp -d)
          cp ${initrd} "''${TMP_INITRD}/initrd"
          chmod +w "''${TMP_INITRD}/initrd"
          (cd ./fixtures; find etc | cpio -o -H newc | gzip -9) >> "''${TMP_INITRD}/initrd"

          ${pkgs.qemu_kvm}/bin/qemu-kvm -name nix-dabei \
            -m 2048 \
            -kernel ${kernel} -initrd "''${TMP_INITRD}/initrd" \
            -append "console=ttyS0 init=/bin/init ${kernelParams}" \
            -no-reboot -nographic \
            -net nic,model=virtio \
            -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
            -drive file=disk.img,format=qcow2,if=virtio \
            -device virtio-rng-pci
          rm -r ''${TMP_INITRD}
        '';
    };
}
