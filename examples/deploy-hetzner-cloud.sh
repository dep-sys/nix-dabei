set -euxo pipefail
# This script serves as an example on how to deploy
# a hetzner cloud server, with dhcp and zfs using nix-dabei.

# Name of the hcloud machine to create
TARGET_NAME="$1"

#TODO SSH_AUTHORIZED_KEYS="$(base64 -w0 < ~/.ssh/id_rsa.pub)"
SSH_AUTHORIZED_KEYS="$(base64 -w0 < ~/.ssh/yubikey.pub)"
# Disks layout and disks to auto-format on boot.
DISKS="zfs-single:/dev/sda"
# NixosConfiguration to install, given as a flake url.
FLAKE_URL="github:dep-sys/nix-dabei/?dir=examples/simple#nixosConfigurations.web-01"


# Build a custom installer from packages.kexec output of the flake in ./custom
kexec="$(nix build .#kexec --json| jq -r '.[].outputs.out')"
# FIXME do you really want to create a cx11 machine in nbg1?
hcloud server create \
    --name "$TARGET_NAME" \
    --type cx11 \
    --image debian-11 \
    --location nbg1 \
    --ssh-key "ssh key"
export TARGET_IP="$(hcloud server ip "$TARGET_NAME")"

# Don't check host keys as those will be ephimeral.
SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# Helper to wait for an ssh server to allow connections (e.g. after reboot)
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
    flake_url=$FLAKE_URL \
    disks=$DISKS \
    ssh_authorized_key=$SSH_AUTHORIZED_KEYS"

# Wait for machine to "reboot" and come back
sleep 1; wait_for_ssh "$TARGET_IP"

# Follow auto-installer output
ssh $SSH_ARGS "root@$TARGET_IP" journalctl -u auto-install -f
