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
nix build .#zfsImage
hcloud server delete installer-test || true
hcloud server create --name installer-test --type cx21 --image debian-11 --location nbg1 --ssh-key "ssh key"
export TARGET_SERVER=$(hcloud server ip installer-test)
echo "Installing to $TARGET_SERVER"
wait_for_ssh "$TARGET_SERVER"
rsync -e "ssh $SSH_ARGS" -Lvz --info=progress2 result/* root@$TARGET_SERVER:
exec ssh $SSH_ARGS -t root@$TARGET_SERVER #|| true # || true because the session is closed by remote host
#wait_for_ssh "$TARGET_SERVER"
#ssh -t $SSH_ARGS root@$TARGET_SERVER do-install # -t for interactive questions
