{
  description = "An operating system generator, based on not-os, focused on installation";
  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
    in
    {
      packages.${system} =
        with pkgs;
        let
          #docs = import ./lib/makeDocs.nix {
          #  inherit pkgs; modules = builtins.attrValues self.nixosModules; # Only document options which are declared inside this flake.
          #  filter = _: opt: opt.declarations == [ ];
          #};
          config = self.nixosConfigurations.default.config;
        in
        {
          # inherit (nixosConfiguration.config.system.build) runvm dist toplevel kexec;
          inherit (config.system.build) toplevel kexecBoot netbootRamdisk dist runvm;
          default = config.system.build.toplevel;
          #docs = docs.all;
          #inherit pkgs;
        };

      apps.${system} =
        let
          scripts = pkgs.lib.mapAttrs makeShellScript {
            lint = "${pkgs.nix-linter}/bin/nix-linter **/*.nix *.nix";
            format = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt **/*.nix *.nix";
            repl = "nix repl repl.nix";
            docs = "cp -L --no-preserve=mode ${self.packages.${system}.docs}/options.md options.md";
          };
          packages = pkgs.lib.mapAttrs makePackageApp {
            vm = { program = "runvm"; };
          };
          makeSimpleApp = program:
            { type = "app"; programm = toString program; };
          makeShellScript = name: content:
            makeSimpleApp (pkgs.writeScript name content);
          makePackageApp = name: { program ? null }:
            makeSimpleApp self.packages.${system}.${program || name};
        in
        scripts // packages // { default = packages.vm; };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ nix-tree ];

      };

      overlays.default = _final: prev: {
       gitMicro = (prev.gitMinimal.override {
          perlSupport = false;
          withManual = false;
          pythonSupport = false;
          withpcre2 = false;
        }).overrideAttrs (_: { doInstallCheck = false; });
      };

      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./configuration.nix ] ++ pkgs.lib.attrValues self.nixosModules;
      };

      nixosModules = {
        environment = import ./modules/environment.nix;
        base = import ./modules/base.nix;
       upstream = {
          imports = [
            "${self}/modules/kexec-boot.nix"
            "${self}/modules/netboot.nix"
         ];
        };
        # Let the generated operating system use our nixpkgs and overlay,
        # but still allow flake users to provide their own.
        nixpkgs = {
          config.nixpkgs = {
            inherit pkgs;
            localSystem = { inherit system; };
          };
        };
      };
    };
}
