## Simple Example
#
# A flake that can be auto-installed with [nix-dabei](https://github.com/dep-sys/nix-dabei),
# and then deployed to with [colmena](https://colmena.cli.rs/stable/).
#
# The implementation should be pretty generic, details specific to nix-dabei
# are in [boot.nix](./boot.nix).
#
# For usage information, see [nix-dabei README](../../README.md).
#
{
  inputs = {
    # We test against nixpgkgs-unstable, but installing (at least) 22.11 should work
    # as well; please file an issue if not!
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # We use colmena/main with its own nixpkgs dependency (no .follows)
    # because we use an interface which isn't in stable yet, and its most likely cached,
    # see below.
    colmena.url = "github:zhaofengli/colmena/main";
  };

  # We install Colmena binaries from cachix.org
  # If you remove it, colmena will most likely be built from source.
  # If you get a warning that this is ignored, it might be due to your user not being in trusted-users.
  #   See https://github.com/NixOS/nix/issues/6672
  nixConfig.extra-substituters = [ "https://colmena.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg=" ];

  # This flake depends only on nixpkgs and colmena, noteably NOT on nix-dabei nor disko
  outputs = { self, nixpkgs, colmena, ... }: let
    # nix-dabei currently supports only x86_64 systems, lets discuss in the
    # issue tracker if you're interested in supporting arm64 and others!
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # TODO we can and should pass down hostname via kernel param
    settings = {
      # FIXME replace with your own hostname
      hostName = "web-01";
      # FIXME replace with your own domain
      domain = "flawed.cloud";
      # TODO ssh pub key: write during auto-install, don't include in system closure?
      sshKeys = pkgs.lib.warn ''
      FIXME replace example ssh public key before you install. This is a well-known,
      # INSECURE key for testing from nixpkgs. It's private key is included
      # in ../../fixtures.
    '' ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVxf7fZiqKDblHFEDxt6X9/rTjBXSn/re6b46S7/e9/ nixbld@localhost"];
    };
  in {
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
