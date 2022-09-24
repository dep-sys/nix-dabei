{
  description = "Easily deploy NixOS with ZFS on remote systems.";

  inputs = {
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit self;} ({withSystem, ...}: {
      imports = [
      ];
      systems = ["x86_64-linux" "aarch64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        packages = {
          zfsImage = self.lib.makeZFSImage {
            inherit system;
            inherit (self.nixosConfigurations.default) config;
          };

          hetznerInstaller = self.lib.makeHetznerInstaller {
            inherit pkgs;
            inherit (self'.packages) zfsImage;
          };
        };

        hydrajobs = self.${system}.packages;

        devShells = {
          deployment = pkgs.mkShell {
            buildInputs = with pkgs; [
              pkgs.hcloud
            ];
          };
          default = self'.devShells.deployment;
        };
      };
      flake = {
        lib = {

          makeZFSImage = {
            system,
            config,
          }:
            withSystem system (ctx @ {pkgs, ...}:
              import ./lib/make-single-disk-zfs-image.nix {
                inherit config pkgs;
                inherit (pkgs) lib;
                inherit (config.x.storage.image) format;
                inherit (config.x.storage.zfs) rootPoolProperties rootPoolFilesystemProperties datasets;
              });

          makeHetznerInstaller = {
            zfsImage,
            pkgs,
          }:
            (import ./lib/providers {inherit pkgs;}).hcloud.makeInstaller {
              inherit pkgs zfsImage;
            };

          makeNixosConfiguration = { modules ? [], extraModules ? [] }:
            withSystem "x86_64-linux" (ctx @ {pkgs, system, ...}:
              inputs.nixpkgs.lib.nixosSystem {
                inherit system pkgs extraModules;
                modules = [ self.nixosModules.default ] ++ modules;
                specialArgs = { inherit inputs; };
              });

        };

        nixosModules = {
          core = ./modules/core.nix;
          nix = ./modules/nix.nix;
          zfs = ./modules/zfs.nix;
          vm = ./modules/vm.nix;
          default = { pkgs, modulesPath, ... }: {
            imports = with self.nixosModules; [
              core
              zfs
              "${modulesPath}/profiles/qemu-guest.nix"
              "${modulesPath}/profiles/headless.nix"
            ];
         };
        };

        nixosConfigurations = {
          default = self.lib.makeNixosConfiguration {};
        };

        templates = {
          hetzner-hcloud = {
            path = ./examples/hetzner-hcloud;
            description = "deployment on hetzner.cloud.";
          };
        };
      };
    });
}
