#!/usr/bin/env nix-shell
#!nix-shell -i bash -p hcloud -p gopass
set -euo pipefail
set -x

SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
wait_for_ssh() {
    until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
        do sleep 1
    done
}
 nix build -L .#zfsImage
hcloud server delete installer-test || true
hcloud server create --name installer-test --type cx21 --image debian-11 --location nbg1 --ssh-key "ssh key"
hcloud server enable-rescue installer-test
hcloud server reboot installer-test
export TARGET_SERVER=$(hcloud server ip installer-test)
echo "Installing to $TARGET_SERVER"
wait_for_ssh "$TARGET_SERVER"
rsync -e "ssh $SSH_ARGS" -Lvz --info=progress2 result/* root@$TARGET_SERVER:

ssh $SSH_ARGS -t root@$TARGET_SERVER <<EOF
test "\$(hostname)" = "installer-test" || exit 1
TARGET_DISK="/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0"

# you could just use dd if you build the image with format=raw, but
# compressed qcow2 with lots of empty space in the image means ~700MB vs 3GB.
qemu-img convert -f qcow2 -O raw -p nixos.root.qcow2 "\$TARGET_DISK"

# "create a new partition table" while using --append is effectively a no-op,
# but it adjusts the disk size in our GPT header, so that auto-expansion can work later on
echo 'label: gpt' | sfdisk --append "\$TARGET_DISK"
EOF

ssh $SSH_ARGS -t root@$TARGET_SERVER "reboot" || true # || true because the session is closed by remote host
wait_for_ssh "$TARGET_SERVER"
