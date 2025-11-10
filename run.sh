set -eu
$(nix-build --no-out-link -A vm)/bin/run-nixos-vm
