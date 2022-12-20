## Custom Example
#
# A flake that can be auto-installed with [nix-dabei](https://github.com/dep-sys/nix-dabei),
# and then deployed to with [colmena](https://colmena.cli.rs/stable/).
#
# It's similar to the [simple example](../simple), but includes a custom
# `myInstaller` derivation to include your own version of nix-dabei with
# overrides and/or extra content.
#
# For usage information, see [nix-dabei README](../../README.md).
#
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    colmena.url = "github:zhaofengli/colmena/main";
    nix-dabei.url = "github:dep-sys/nix-dabei/main";
  };

 nixConfig.extra-substituters = [ "https://colmena.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg=" ];

  outputs = { self, nixpkgs, colmena, nix-dabei, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    settings = {
      # FIXME replace with your own hostname
      hostName = "storage-01";
      # FIXME replace with your own domain
      domain = "flawed.cloud";
      # TODO ssh pub key: write during auto-install, don't include in system closure?
      sshKeys = pkgs.lib.warn ''
      FIXME replace example ssh public key before you install. This is a well-known,
      # INSECURE key for testing from nixpkgs. It's private key is included
      # in ../../fixtures.
    '' ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVxf7fZiqKDblHFEDxt6X9/rTjBXSn/re6b46S7/e9/ nixbld@localhost"];
    };

    # Build a derivation for our custom installer, using nixos modules
    # to add or remove tools and settings for the initrd used to bootstrap
    # the final system.
    myInstaller = nix-dabei.lib.makeInstaller [
      ({ config, pkgs, lib, ... }: {
        # We add e1000e to have networking work in nix-dabei on a physical
        # machine with an intel gigabit ethernet adapter.
        boot.initrd.kernelModules = [ "e1000e" ];

        boot.initrd.systemd.extraBin = {
              # Extra binaries that will be available in your nix-dabei
              ip = "${pkgs.iproute2}/bin/ip";
              sfdisk = "${pkgs.util-linux}/bin/sfdisk";
              vim = "${pkgs.vim}/bin/vi";
        };
      })
    ];
  in {
    packages.${system} = {
      inherit (myInstaller.config.system.build) kexec;
    };
    apps.${system} = {
      inherit (colmena.apps.${system}) colmena;
    };

    nixosConfigurations = self.colmenaHive.nodes;
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = pkgs;
      };

      web-01 = { name, nodes, pkgs, lib, config, ... }: {
        config = {
          networking.hostName = "${settings.hostName}";
          networking.domain = "${settings.domain}";
        };
      };

      defaults = { config, lib, modulesPath, ... }: {
        imports = [
          "${modulesPath}/profiles/qemu-guest.nix"
          ./boot.nix
        ];
        config = {
          networking.hostId = lib.mkDefault (builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName));
          networking.interfaces.eth0.useDHCP = lib.mkDefault true;
          users.users.root.openssh.authorizedKeys.keys = lib.mkDefault settings.sshKeys;

          deployment = {
            targetHost = config.networking.fqdn;
            targetPort = 22;
            targetUser = "root";
          };

          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };

          time.timeZone = lib.mkDefault "UTC";
          nix.extraOptions = "experimental-features = nix-command flakes";
          environment.systemPackages = with pkgs; [
            vim tmux htop ncdu fd ripgrep fzf jq
          ];
          system.stateVersion = lib.mkDefault "22.11";
        };
      };
    };
  };
}
