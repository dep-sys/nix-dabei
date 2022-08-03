# To use this file run "nix repl repl.nix" or,
# in this flake: "nix run repl"
let
  flake = builtins.getFlake (toString ./.);
  nixpkgs = flake.inputs.nixpkgs;
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
  lib = flake.inputs.nixpkgs.lib;
  configs = flake.nixosConfigurations;
in
{ inherit flake nixpkgs pkgs lib configs; }
