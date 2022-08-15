{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dabei = {
      url = "github:dep-sys/nix-dabei/zfs-disk-image";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, nix-dabei, ... } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {

    packages.${system} = {
      zfsImage = nix-dabei.lib.makeZFSImage {
        inherit system;
        inherit (self.nixosConfigurations.my-little-webserver) config;
      };
      hetznerInstaller = nix-dabei.lib.makeHetznerInstaller {
        inherit pkgs;
        inherit (self.packages.${system}) zfsImage;
      };
    };

    nixosConfigurations = {
      my-little-webserver = nix-dabei.lib.makeNixosConfiguration {
        modules = [
          ({ config, pkgs, lib, ... }: {
            services.nginx.enable = true;
          })
        ];
      };
    };
  };
}
