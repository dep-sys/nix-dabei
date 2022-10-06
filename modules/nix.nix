{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
    }
    # config is only available after the first rebuild
    // (if config.x.instance-data ? flake-url
        then { config.to = config.x.instance-data.flake-url; }
        else {});
    extraOptions = "experimental-features = nix-command flakes";
  };
}
