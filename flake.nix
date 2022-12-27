{
  description = "A minimal initrd, capable of running sshd and nix.";
  # this is a temporary fork including the changes from
  # https://github.com/NixOS/nixpkgs/pull/169116/files
  # (rebased on master from time to time)
  inputs.nixpkgs.url = "github:phaer/nixpkgs/nix-dabei";
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} =
        let
         config = self.nixosConfigurations.default.config;
        in
          {
            inherit (config.system.build)
              kexec
              kexecTarball
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

      nixosModules = {
        build = import ./build.nix;
        module = import ./module.nix;
      };
    };
}
