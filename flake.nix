{
  description = "An operating system generator, based on not-os, focused on installation";
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
         tests = pkgs.lib.mapAttrs'
           (n: v: pkgs.lib.nameValuePair "test-${n}" v)
           (import ./tests.nix { inherit pkgs system self; });

        in
        {
          inherit (config.system.build)
            dist
            runvm;
          ssh-test = (import ./ssh-test.nix { inherit pkgs; lib = nixpkgs.lib; inherit (self) nixosModules; }); #.driverInteractive;
          default = config.system.build.toplevel;
        } // tests;

      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          { _module.args = { disko = disko.lib; }; }
          ./configuration.nix
        ] ++ pkgs.lib.attrValues self.nixosModules;
      };

      nixosModules = {
        build = import ./modules/build.nix;
        installer = import ./modules/installer.nix;
      };
    };
}
