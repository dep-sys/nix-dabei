{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dabei.url = "github:dep-sys/nix-dabei";
    nix-dabei.inputs.nixpkgs.follows = "nixpkgs";
    colmena.url = "github:zhaofengli/colmena/stable";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-dabei, colmena, ... } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {

    packages.${system}.terraform = let
      terraform = pkgs.terraform.withPlugins (p: [p.cloudflare p.hcloud]);
    in pkgs.writers.writeBashBin "terraform" ''
      ${pkgs.terranix}/bin/terranix --quiet infra.nix > infra.tf.json
      ${terraform}/bin/terraform "$@"
    '';
    defaultPackage.${system} = self.packages.${system}.terraform;

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with self.packages.${system}; [
        terraform
      ];
    };


    apps.${system}.colmena = colmena.apps.${system}.colmena;
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
          ({ config, pkgs, lib, ... }: {
            users.users.root.password = "hunter2";
            services.openssh.passwordAuthentication = true;
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
