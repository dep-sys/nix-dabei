set -euxo pipefail

TARGET_NAME="$1"

SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
wait_for_ssh() {
    until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
        do sleep 1
    done
}

kexec="$(nix build .#kexec --json| jq -r '.[].outputs.out')"

hcloud server create \
    --name "$TARGET_NAME" \
    --type cx11 \
    --image debian-11 \
    --location nbg1 \
    --ssh-key "ssh key"

export TARGET_SERVER="$(hcloud server ip "$TARGET_NAME")"
wait_for_ssh "$TARGET_SERVER"
rsync \
    -e "ssh $SSH_ARGS" \
    -Lrvz \
    --info=progress2 \
    "${kexec}/" \
    root@$TARGET_SERVER:


ssh_authorized_key="$(base64 -w0 < ~/.ssh/yubikey.pub)"
flake_url="github:dep-sys/nix-dabei/auto-installer?dir=demo#nixosConfigurations.web-01"
ssh $SSH_ARGS "root@$TARGET_SERVER" "./kexec-boot ssh_authorized_key=$ssh_authorized_key flake_url=$flake_url"
wait_for_ssh "$TARGET_SERVER"

ssh $SSH_ARGS "root@$TARGET_SERVER" journalctl -u auto-installer -f
