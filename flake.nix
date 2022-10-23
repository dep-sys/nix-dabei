{
  description = "A minimal initrd, capable of running sshd and nix.";
  # needs https://github.com/NixOS/nixpkgs/pull/169116/files
  #inputs.nixpkgs.url = "nixpkgs/nixos-22.05";
  inputs.nixpkgs.url = "github:ElvishJerricco/nixpkgs/systemd-stage-1-networkd";
  inputs.disko.url = "github:nix-community/disko/master";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, disko }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} =
        with pkgs;
        let
         config = self.nixosConfigurations.default.config;
         tests = import ./tests.nix { inherit pkgs system self; };
        in
          tests // {
            inherit (config.system.build)
              kexec
              installerVM;
            default = config.system.build.kexec;
          };

      lib.makeSystem = modules: nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = (pkgs.lib.attrValues self.nixosModules) ++ modules;
      };


      nixosConfigurations.default = self.lib.makeSystem [
          ./configuration.nix
      ];

      nixosModules = {
        disko = { _module.args = { disko = disko.lib; }; };
        build = import ./modules/build.nix;
        installer = import ./modules/installer.nix;
      };
    };
}
