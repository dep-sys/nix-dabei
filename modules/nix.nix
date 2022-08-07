{
  pkgs,
  inputs,
  ...
}: {
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    registry.nixpkgs.flake = inputs.nixpkgs;
    registry.nix-dabei.to  = {
      type = "github";
      owner = "dep-sys";
      repo = "nix-dabei";
      ref = "zfs-disk-image";
    };
    extraOptions = "experimental-features = nix-command flakes";
  };
}
