# To use this file run "nix repl repl.nix" or,
# in this flake: "nix run repl"
let
  flake = builtins.getFlake (toString ./.);
  inherit (flake.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  pkgs = import nixpkgs {inherit system;};
  configs = flake.nixosConfigurations;
in {inherit flake nixpkgs pkgs lib configs;}
