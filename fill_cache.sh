export CACHIX_CACHE="nix-dabei"
export CACHIX_AUTH_TOKEN="$(gopass show -o cachix-nix-dabei)"
nix flake archive --json \
  | jq -r '.path,(.inputs|to_entries[].value.path)' \
  | nix run nixpkgs#cachix push $CACHIX_CACHE
nix build .#kexec --json \
  | jq -r '.[].outputs | to_entries[].value' \
  | nix run nixpkgs#cachix push $CACHIX_CACHE
