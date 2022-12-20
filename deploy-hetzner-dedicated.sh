set -euxo pipefail

export TARGET_SERVER="${1:-$TARGET_SERVER}"
export TARGET_IP="${2:-$TARGET_IP}"
export TARGET_GATEWAY="${3:-$TARGET_GATEWAY}"
export TARGET_NETMASK="${4:-$TARGET_NETMASK}"
export TARGET_DEVICE="${5:-$TARGET_DEVICE}"

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
flake_url="github:dep-sys/nix-dabei/?dir=examples/custom#nixosConfigurations.storage-01"

# ip=<client-ip>:<nfs-server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>
static_ip="${TARGET_IP}::${TARGET_GATEWAY}:${TARGET_NETMASK}:${TARGET_SERVER}:${TARGET_DEVICE}"
ssh $SSH_ARGS "root@$TARGET_SERVER" "./kexec-boot ip=$static_ip flake_url=$flake_url disks=zfs-mirror:/dev/sda,/dev/sdb ssh_authorized_key=$ssh_authorized_key"
wait_for_ssh "$TARGET_SERVER"

ssh $SSH_ARGS "root@$TARGET_SERVER" journalctl -u auto-installer -f
