{
  description = "A minimal initrd, capable of running sshd and nix.";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
  };
  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake {inherit inputs;} {

      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        ./modules/flake-parts/formatter.nix
        ./modules/flake-parts/nixosConfigurations
        ./modules/flake-parts/nixosModules
        ./modules/flake-parts/packages
        ./modules/flake-parts/lib
      ];
    };
}

