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
          zfsImage =
            let
              inherit (self.nixosConfigurations.default) config;
            in
              import "${pkgs.path}/nixos/lib/make-single-disk-zfs-image.nix" {
                inherit config pkgs;
                inherit (pkgs) lib;
                format = "qcow2-compressed";
                #rootPoolName = "tank-${config.networking.hostId}";
                # rootPool properties are mostly cargo-culted from
                # https://openzfs.github.io/openzfs-docs/Getting%20Started/NixOS/Root%20on%20ZFS/2-system-installation.html
                # and may require adaption for your setup. E.g. try lz4 for less cpu consumption and a bit less
                # compression.
                rootPoolProperties = {
                  ashift = 12;
                  autotrim = "on";
                  autoexpand = "on";
                };
                rootPoolFilesystemProperties = {
                  acltype = "posixacl";
                  compression = "zstd";
                  dnodesize = "auto";
                  normalization="formD";
                  relatime = "on";
                  xattr = "sa";
                };
                datasets = self.nixosConfigurations.default.config.x.storage.zfs.datasets;
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
