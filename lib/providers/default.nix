{pkgs, ...}: {
  hcloud = import ./hcloud.nix { inherit pkgs;};
}
