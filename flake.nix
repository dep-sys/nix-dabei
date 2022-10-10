{
  description = "An operating system generator, based on not-os, focused on installation";
  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";
  inputs.disko.url = "github:nix-community/disko/master";

  outputs = { self, nixpkgs, disko }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [self.overlays.default]; };
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
            initialRamdisk
            runvm;
          ssh-test = (import ./ssh-test.nix { inherit pkgs; lib = nixpkgs.lib; inherit (self) nixosModules; }); #.driverInteractive;
          default = config.system.build.toplevel;
        } // tests;

      apps.${system} =
        let
          scripts = pkgs.lib.mapAttrs makeShellScript {
            lint = "${pkgs.nix-linter}/bin/nix-linter **/*.nix *.nix";
            format = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt **/*.nix *.nix";
            repl = "nix repl repl.nix";
            docs = "cp -L --no-preserve=mode ${self.packages.${system}.docs}/options.md options.md";
          };
          packages = pkgs.lib.mapAttrs makePackageApp {
            vm = { program = self.packages.${system}.runvm; };
          };
          makeSimpleApp = program:
            { type = "app"; program = toString program; };
          makeShellScript = name: content:
            makeSimpleApp (pkgs.writeScript name content);
          makePackageApp = name: { program ? null }:
            makeSimpleApp self.packages.${system}.${program || name};
        in
        scripts // packages // { default = packages.vm; };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ nix-tree nvd ];
      };

      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          { _module.args = { disko = disko.lib; }; }
          ./configuration.nix
        ] ++ pkgs.lib.attrValues self.nixosModules;
      };

      nixosConfigurations.with-minimal-git =
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            ./configuration.nix
            ({pkgs, ...}: {
              environment.systemPackages = [
                pkgs.gitMicro
              ];
            })
          ] ++ pkgs.lib.attrValues self.nixosModules;
        };

      nixosModules = {
        base = import ./modules/base.nix;
        initrd = import ./modules/initrd.nix;
        build = import ./modules/build.nix;
        installer = import ./modules/installer.nix;
      };

      overlays.default = final: prev: {
        gitMicro = (pkgs.gitMinimal.override {
          perlSupport = false;
          withManual = false;
          pythonSupport = false;
          withpcre2 = false;
        }).overrideAttrs (_: { doInstallCheck = false; });

        zfs = prev.zfs;
      };

    };
}
