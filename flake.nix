{
  description = "Minimal operating systems based on not-os";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ ]; };
      lib = nixpkgs.lib;

      baseModules = [
        ./modules/base.nix
        ./modules/system-path.nix
        ./modules/stage-1.nix
        ./modules/stage-2.nix
        ./modules/runit.nix
        (nixpkgs + "/nixos/modules/system/etc/etc.nix")
        (nixpkgs + "/nixos/modules/system/activation/activation-script.nix")
        (nixpkgs + "/nixos/modules/misc/nixpkgs.nix")
        (nixpkgs + "/nixos/modules/system/boot/kernel.nix")
        (nixpkgs + "/nixos/modules/misc/assertions.nix")
        (nixpkgs + "/nixos/modules/misc/lib.nix")
        (nixpkgs + "/nixos/modules/config/sysctl.nix")
        ./modules/systemd-compat.nix
        ({ ... }: {
          config.nixpkgs.localSystem = { inherit system; };
        })
      ];

      evalConfig = modules: pkgs.lib.evalModules {
        prefix = [];
        check = true;
        modules = modules ++ baseModules;
        args = {};
      };
    in {
      packages.${system} = rec {
        node = evalConfig [ ./configuration.nix ];
        run-node-vm = node.config.system.build.runvm;
      };
      defaultPackage.${system} = self.packages.${system}.run-node-vm;

      nixosModules = {};
    };
}
