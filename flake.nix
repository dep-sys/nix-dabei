{
  description = "A minimal initrd, capable of running sshd and nix.";
  # this is a temporary fork including the changes from
  # https://github.com/NixOS/nixpkgs/pull/169116/files
  # (rebased on master from time to time)
  inputs.nixpkgs.url = "github:phaer/nixpkgs/nix-dabei";
  # https://github.com/nix-community/disko/pull/72
  inputs.disko.url = "github:phaer/disko/allow-variables";
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
              vm;
            default = config.system.build.kexec;
          };

      lib.makeInstaller =
        modules: nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = (builtins.attrValues self.nixosModules) ++ modules;
        };

      nixosConfigurations.default = self.lib.makeInstaller [
        "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"

      ];

      diskoConfigurations = {
        zfs-simple = import ./disk-layouts/zfs-simple.nix;
        zfs-mirror = import ./disk-layouts/zfs-mirror.nix;
      };

      nixosModules = {
        disko._module.args = {
          inherit disko;
          inherit (self) diskoConfigurations;
        };
        build = import ./modules/build.nix;
        core = import ./modules/core.nix;
        auto-installer = import ./modules/auto-installer.nix;
      };
    };
}
