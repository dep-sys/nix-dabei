{
  description = "Description for the project";

  inputs = {
    flake-parts.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit self; } ({ withSystem, ... }: {
      imports = [
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: rec {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        packages = {
          zfsImage = self.lib.makeZFSImage {
            inherit system;
            inherit (self.nixosConfigurations.default) config;
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
          default = devShells.deployment;
        };

      };
      flake = {
        lib = {
          makeZFSImage = { system, config }:
            withSystem system (ctx@{ pkgs, ... }:
              import "${inputs.nixpkgs}/nixos/lib/make-single-disk-zfs-image.nix" {
                inherit config pkgs;
                inherit (pkgs) lib;
                inherit (config.x.image) format;
                inherit (config.x.storage.zfs) rootPoolProperties rootPoolFilesystemProperties datasets;
              });
        };

        nixosModules = {
          core = ./modules/core.nix;
          nix = ./modules/nix.nix;
          zfs = ./modules/zfs.nix;
          vm = ./modules/vm.nix;
        };

        nixosConfigurations = {
          default = withSystem "x86_64-linux" (ctx@{ pkgs, ... }:
            pkgs.nixos ({ config, lib, packages, pkgs, modulesPath, ... }: {
              _module.args.inputs = inputs;
              imports = with self.nixosModules; [
                core
                zfs
                "${modulesPath}/profiles/qemu-guest.nix"
                "${modulesPath}/profiles/headless.nix"
              ];

              # Enable the serial console on tty1
              systemd.services."serial-getty@tty1".enable = true;

              environment.systemPackages = with pkgs; lib.mkDefault [
                vim tmux htop ncdu curl dnsutils jq fd ripgrep gawk gnused git
              ];
           }));
        };

      };
    });
}
