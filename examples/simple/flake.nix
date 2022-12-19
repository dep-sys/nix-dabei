{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    colmena.url = "github:zhaofengli/colmena/main";
  };

  # If you get a warning that this is ignored, it might be
  # due to your user not being in trusted-users. See
  # https://github.com/NixOS/nix/issues/6672
  nixConfig.extra-substituters = [ "https://colmena.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg=" ];

  outputs = { self, nixpkgs, colmena, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # TODO ssh pub key: write during auto-install, don't include in system closure?
    sshKeys = pkgs.lib.warn ''
      FIXME replace this ssh key before you install. This is a well-known,
      # INSECURE key for testing, from nixpkgs. It's private key is included
      # in ../../fixtures.
    '' ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVxf7fZiqKDblHFEDxt6X9/rTjBXSn/re6b46S7/e9/ nixbld@localhost"];
  in {
    apps.${system} = {
      colmena = colmena.apps.${system}.default;
    };

    nixosConfigurations = self.colmenaHive.nodes;
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = pkgs;
      };

      web-01 = { name, nodes, pkgs, lib, config, modulesPath, ... }: {
        imports = [
          "${modulesPath}/profiles/qemu-guest.nix"
          ./boot.nix
        ];

        config = {
          deployment = {
            targetHost = "${name}.${config.my.domain}";
            targetPort = 22;
            targetUser = "root";
            buildOnTarget = true;
          };

          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };

          time.timeZone = "UTC";
          system.stateVersion = "22.11";
          users.users.root.openssh.authorizedKeys.keys = sshKeys;

          networking.hostName = "${name}";
          networking.hostId = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);
          networking.interfaces.eth0.useDHCP = true;

          environment.systemPackages = with pkgs; [
            vim tmux htop ncdu fd ripgrep fzf jq
          ];
          nix.extraOptions = "experimental-features = nix-command flakes";
        };
      };
    };
  };
}
