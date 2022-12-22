set -euxo pipefail
# This script serves as an example on how to deploy
# a dedicated hetzner server, with a static ipv4 adress and zfs
# mirrored on both disks, using nix-dabei.

#TODO SSH_AUTHORIZED_KEYS="$(base64 -w0 < ~/.ssh/id_rsa.pub)"
SSH_AUTHORIZED_KEYS="$(base64 -w0 < ~/.ssh/yubikey.pub)"
# Disks layout and disks to auto-format on boot.
DISKS="zfs-mirror:/dev/sda,/dev/sdb"
# NixosConfiguration to install, given as a flake url.
FLAKE_URL="github:dep-sys/nix-dabei/?dir=examples/custom#nixosConfigurations.storage-01"

# set a static ipv4 adress as an example, you could also set `ip=:::::eth0:dhcp` or
# remove the ip parameter competely.
TARGET_IP="${1:-$TARGET_IP}"
TARGET_GATEWAY="${2:-$TARGET_GATEWAY}"
TARGET_NETMASK="${3:-$TARGET_NETMASK}"
TARGET_DEVICE="${4:-$TARGET_DEVICE}"
# ip=<client-ip>:<nfs-server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>
STATIC_IP="${TARGET_IP}::${TARGET_GATEWAY}:${TARGET_NETMASK}:${TARGET_DEVICE}"

# Build a custom installer from packages.kexec output of the flake in ./custom
kexec="$(nix build ./examples/custom#kexec --json| jq -r '.[].outputs.out')"

# Don't check host keys as those will be ephimeral.
SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# Helper to wait for an ssh server to allow connections (e.g. after reboot).
wait_for_ssh() {
    until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
        do sleep 1
    done
}


wait_for_ssh "$TARGET_IP"
# Copy our installer to the target host
rsync \
    -e "ssh $SSH_ARGS" \
    -Lrvz \
    --info=progress2 \
    "${kexec}/" \
    root@$TARGET_IP:

# Execute ./kexec-boot with variables evaluated on the client side to configure the installer
ssh $SSH_ARGS "root@$TARGET_IP" "./kexec-boot \
    ip=$STATIC_IP \
    flake_url=$FLAKE_URL \
    disks=$DISKS \
    ssh_authorized_key=$SSH_AUTHORIZED_KEYS"

# Wait for nixos to come up after kexec
wait_for_ssh "$TARGET_IP"

# Follow auto-installer output
ssh $SSH_ARGS "root@$TARGET_IP" journalctl -u auto-installer -f
