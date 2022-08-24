{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dabei = {
      url = "github:dep-sys/nix-dabei";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    colmena.url = "github:zhaofengli/colmena";
  };

  outputs = { self, nixpkgs, nix-dabei, colmena, ... } @ inputs: let
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

    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          inherit system;
        };
        specialArgs = { inherit inputs; };
      };
    } // builtins.mapAttrs (name: value: {
      nixpkgs.system = value.config.nixpkgs.system;
      imports = value._module.args.modules;
    }) (self.nixosConfigurations);

    nixosConfigurations = {
      my-little-webserver = nix-dabei.lib.makeNixosConfiguration {
        extraModules = [colmena.nixosModules.deploymentOptions];
        modules = [
          ({ config, pkgs, lib, ... }:
            {
            deployment.targetHost = config.x.instance-data.data.public-ipv4;
            x.instance-data.storedPath = ./hosts/my-little-webserver.json;
            networking.hostName = "my-little-webserver";
            services.nginx.enable = true;
          })
        ];
      };
    };
  };
}
