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

        devShells = {
          deployment = pkgs.mkShell {
            buildInputs = with pkgs; [
              pkgs.hcloud
            ];
            shellHook = ''
              # FIXME: use your own token here
              export HCLOUD_TOKEN="$(gopass show -o fancy.systems/external/hetzner.cloud)"
            '';
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

          makeNixosConfiguration = { modules ? [] }:
            withSystem "x86_64-linux" (ctx @ {pkgs, ...}:
              pkgs.nixos {
                _module.args.inputs = inputs;
                imports = [ self.nixosModules.default ] ++ modules;
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

            environment.systemPackages = with pkgs;
              lib.mkDefault [
                vim
                tmux
                htop
                ncdu
                curl
                dnsutils
                jq
                fd
                ripgrep
                gawk
                gnused
                git
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
