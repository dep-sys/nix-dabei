{
  pkgs,
  lib,
  inputs,
  ...
}: let
  nixDabeiRepo = {
    type = "github";
    owner = "dep-sys";
    repo = "nix-dabei";
    ref = "main";
  };
in {
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      nix-dabei.to = nixDabeiRepo;
      config.to = lib.mkDefault nixDabeiRepo;
    };
    extraOptions = "experimental-features = nix-command flakes";
  };
}
