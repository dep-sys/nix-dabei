{
  description = "Description for the project";

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

          hetznerInstaller = pkgs.linkFarmFromDrvs "hetzner-installer" [
            self'.packages.zfsImage
            (pkgs.writeShellScript "create-nixos-machine.sh" ''
              set -euxo pipefail

              SSH_ARGS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
              wait_for_ssh() {
                  until ssh -o ConnectTimeout=2 $SSH_ARGS root@"$1" "true"
                      do sleep 1
                  done
              }

              # TODO remove or prompt
              hcloud server delete installer-test \
                  || true

              hcloud server create \
                  --start-after-create=false \
                  --name installer-test \
                  --type cx11 \
                  --image debian-11 \
                  --location nbg1 \
                  --ssh-key "ssh key"

              hcloud server enable-rescue \
                  --ssh-key "ssh key" \
                  installer-test

              hcloud server poweron installer-test

              export TARGET_SERVER=$(hcloud server ip installer-test)
              wait_for_ssh "$TARGET_SERVER"
              test "$(ssh $SSH_ARGS root@$TARGET_SERVER hostname)" = "rescue" \
                  || exit 1

              echo "Copying to $TARGET_SERVER"
              rsync \
                  -e "ssh $SSH_ARGS" \
                  -Lvz \
                  --info=progress2 \
                  "./result/nixos-disk-image/nixos.root.qcow2" \
                  "./result/wipe-disk-and-install.sh" \
                  root@$TARGET_SERVER:

              echo "Installing to $TARGET_SERVER"
              echo "ssh $SSH_ARGS root@$TARGET_SERVER -t 'bash ./wipe-disk-and-install.sh'"
            '')
            (pkgs.writeScript "wipe-disk-and-install.sh" ''
              #!/usr/bin/env bash
              set -euxo pipefail

              test "$(hostname)" = "rescue" || exit 1
              TARGET_DISK="/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0-0-0-0"

              # you could just use dd if you build the image with format=raw, but
              # compressed qcow2 with lots of empty space in the image means ~700MB vs 3GB.
              qemu-img convert -f qcow2 -O raw -p nixos.root.qcow2 "$TARGET_DISK"

              # "create a new partition table" while using --append is effectively a no-op,
              # but it adjusts the disk size in our GPT header, so that auto-expansion can work later on
              echo 'label: gpt' | sfdisk --append "$TARGET_DISK"

              reboot
            '')
          ];
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
              import "${inputs.nixpkgs}/nixos/lib/make-single-disk-zfs-image.nix" {
                inherit config pkgs;
                inherit (pkgs) lib;
                inherit (config.x.storage.image) format;
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
          default = withSystem "x86_64-linux" (ctx @ {pkgs, ...}:
            pkgs.nixos ({
              config,
              lib,
              packages,
              pkgs,
              modulesPath,
              ...
            }: {
              _module.args.inputs = inputs;
              imports = with self.nixosModules; [
                core
                zfs
                "${modulesPath}/profiles/qemu-guest.nix"
                "${modulesPath}/profiles/headless.nix"
              ];

              # Enable the serial console on tty1
              systemd.services."serial-getty@tty1".enable = true;

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
            }));
        };
      };
    });
}
