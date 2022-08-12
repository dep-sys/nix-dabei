{pkgs}:
rec {
  description = "hetzner.cloud, see https://docs.hetzner.cloud/#server-metadata";

  fetchInstanceData = path: pkgs.writeShellScriptBin "hcloud-fetch-instance-data.sh" ''
      for i in {1..60};
      do
          # wait until network is actually up
          if ${pkgs.curl}/bin/curl -s http://169.254.169.254; then
            break
          fi
          sleep 1
      done

      ${pkgs.curl}/bin/curl http://169.254.169.254/hetzner/v1/metadata \
      | ${pkgs.yq}/bin/yq '.' \
      | tee ${path}
  '';

  installScript = pkgs.writeShellScript "hcloud-create-machine.sh" ''
      set -euxo pipefail

      SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
      wait_for_ssh() {
          until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
              do sleep 1
          done
      }

      # TODO remove or prompt
      hcloud server delete installer-test \
          || true

      hcloud server create \
          --start-after-create=false \
          --name installer-test \
          --type cx11 \
          --image debian-11 \
          --location nbg1 \
          --ssh-key "ssh key"

      hcloud server enable-rescue \
          --ssh-key "ssh key" \
          installer-test

      hcloud server poweron installer-test

      export TARGET_SERVER=$(hcloud server ip installer-test)
      wait_for_ssh "$TARGET_SERVER"
      test "$(ssh $SSH_ARGS root@$TARGET_SERVER hostname)" = "rescue" \
          || exit 1

      echo "Copying to $TARGET_SERVER"
      rsync \
          -e "ssh $SSH_ARGS" \
          -Lvz \
          --info=progress2 \
          "./result/nixos-disk-image/nixos.root.qcow2" \
          "./result/hcloud-do-install.sh" \
          root@$TARGET_SERVER:

      echo "Installing to $TARGET_SERVER"
      ssh $SSH_ARGS root@$TARGET_SERVER -t 'bash ./hcloud-do-install.sh'
  '';
  remoteScript = pkgs.writeScript "hcloud-do-install.sh" ''
      #!/usr/bin/env bash
      set -euxo pipefail

      test "$(hostname)" = "rescue" || exit 1
      TARGET_DISK="/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0"

      # you could just use dd if you build the image with format=raw, but
      # compressed qcow2 with lots of empty space in the image means ~700MB vs 3GB.
      qemu-img convert -f qcow2 -O raw -p nixos.root.qcow2 "$TARGET_DISK"

      # "create a new partition table" while using --append is effectively a no-op,
      # but it adjusts the disk size in our GPT header, so that auto-expansion can work later on
      echo 'label: gpt' | sfdisk --append "$TARGET_DISK"

      reboot
  '';

  makeInstaller = {
    pkgs,
    zfsImage
  }: pkgs.linkFarmFromDrvs "hcloud-installer" [
    zfsImage
    installScript
    remoteScript
    (pkgs.vmTools.makeImageTestScript "")
  ];
}
