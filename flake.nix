{
  description = "A minimal initrd, capable of running sshd and nix.";
  # this is a temporary fork including the changes from
  # https://github.com/NixOS/nixpkgs/pull/169116/files
  # and a small patch in https://github.com/NixOS/nixpkgs/pull/197382
  # (rebased on master from time to time)
  inputs.nixpkgs.url = "github:phaer/nixpkgs/nix-dabei";
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

      lib.installerModules = [
        self.nixosModules.disko
        self.nixosModules.build
        self.nixosModules.installer
        ./configuration.nix
      ];

      lib.makeInstaller =
        modules: nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = self.lib.installerModules ++ modules;
        };

      nixosConfigurations.default = self.lib.makeInstaller [
          ./configuration.nix
      ];

      nixosModules = {
        disko = { _module.args = { disko = disko.lib; }; };
        build = import ./modules/build.nix;
        installer = import ./modules/installer.nix;
        instanceDefaults = import ./modules/instanceDefaults.nix;
      };
    };
}
