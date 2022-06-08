# To use this file run "nix repl repl.nix" or,
let
  flake = builtins.getFlake (toString ./.);
  nixpkgs = flake.inputs.nixpkgs;
  system = builtins.currentSystem;
  pkgs = import nixpkgs { inherit system; };
  lib = pkgs.lib;
in
{
  inherit flake nixpkgs pkgs lib;
  inherit (flake) nixosModules overlay;
  packages = flake.packages.${system};
}
