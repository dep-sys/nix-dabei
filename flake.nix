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
        self.nixosModules.build
        self.nixosModules.core
      ];

      lib.makeInstaller =
        modules: nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = self.lib.installerModules ++ modules;
        };

      lib.diskLayouts = {
        zfs-simple = ./disk-layouts/zfs-simple.nix;
      };

      nixosConfigurations.default = self.lib.makeInstaller [
        "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"

      ];

      nixosModules = {
        build = import ./modules/build.nix;
        core = import ./modules/core.nix;
        instanceDefaults = import ./modules/instanceDefaults.nix;
      };
    };
}
