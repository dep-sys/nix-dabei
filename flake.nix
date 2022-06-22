{
  description = "An operating system generator, based on not-os, focused on installation";
  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} =
        with pkgs;
        let
         config = self.nixosConfigurations.default.config;
         tests = pkgs.lib.mapAttrs'
           (n: v: pkgs.lib.nameValuePair "test-${n}" v)
           (import ./tests.nix { inherit nixpkgs system self; });

        in
        {
          inherit (config.system.build)
            toplevel
            dist
            runvm;
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
        modules = [ ./configuration.nix ] ++ pkgs.lib.attrValues self.nixosModules;
      };

      nixosConfigurations.with-minimal-git =
        let
          gitMicro = (pkgs.gitMinimal.override {
            perlSupport = false;
            withManual = false;
            pythonSupport = false;
            withpcre2 = false;
          }).overrideAttrs (_: { doInstallCheck = false; });

        in nixpkgs.lib.nixosSystem {
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
        build = import ./modules/build.nix;
      };
    };
}
