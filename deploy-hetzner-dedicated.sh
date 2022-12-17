set -euxo pipefail

TARGET_SERVER="$1"

SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
wait_for_ssh() {
    until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
        do sleep 1
    done
}

kexec="$(nix build .#kexec --json| jq -r '.[].outputs.out')"

wait_for_ssh "$TARGET_SERVER"
rsync \
    -e "ssh $SSH_ARGS" \
    -Lrvz \
    --info=progress2 \
    "${kexec}/" \
    root@$TARGET_SERVER:


ssh_authorized_key="$(base64 -w0 < ~/.ssh/yubikey.pub)"
flake_url="github:dep-sys/nix-dabei/disko-runtime?dir=demo#nixosConfigurations.web-01"
ssh $SSH_ARGS "root@$TARGET_SERVER" "./kexec-boot ssh_authorized_key=$ssh_authorized_key flake_url=$flake_url disks=zfs-mirror:/dev/sda,/dev/sdb"
wait_for_ssh "$TARGET_SERVER"

ssh $SSH_ARGS "root@$TARGET_SERVER" journalctl -u auto-installer -f
