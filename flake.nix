{
  description = "A minimal initrd, capable of running sshd and nix.";
  # https://github.com/NixOS/nixpkgs/pull/169116/files
  inputs.nixpkgs.url = "github:ElvishJerricco/nixpkgs/systemd-stage-1-networkd";

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
