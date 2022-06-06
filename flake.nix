{
  description = "Minimal operating systems based on not-os";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
      lib = nixpkgs.lib;

      baseModules = [
        ./modules/base.nix
        ./modules/system-path.nix
        ./modules/stage-1.nix
        ./modules/stage-2.nix
        ./modules/runit.nix
        (nixpkgs + "/nixos/modules/system/etc/etc-activation.nix")
        (nixpkgs + "/nixos/modules/system/activation/activation-script.nix")
        (nixpkgs + "/nixos/modules/misc/nixpkgs.nix")
        (nixpkgs + "/nixos/modules/system/boot/kernel.nix")
        (nixpkgs + "/nixos/modules/misc/assertions.nix")
        (nixpkgs + "/nixos/modules/misc/lib.nix")
        (nixpkgs + "/nixos/modules/config/sysctl.nix")
        ./modules/systemd-compat.nix
        ({ ... }: {
          config.nixpkgs = {
            inherit pkgs;
            localSystem = { inherit system; };
          };
        })
      ];

      evalConfig = modules: pkgs.lib.evalModules {
        prefix = [];
        modules = modules ++ baseModules;
      };
    in {
      overlay = _final: prev: {
        procps = prev.procps.override { withSystemd = false; };
        util-linux = prev.util-linux.override { systemd = null; systemdSupport = false; ncursesSupport = false; nlsSupport = false;};
        dhcpcd = prev.dhcpcd.override { udev = null; };
        libusb = prev.libusb.override { enableUdev = false; };
        rng-tools = prev.rng-tools.override { withPkcs11 = false; withRtlsdr = false; };
        openssh = prev.openssh.override { withFIDO = false; withKerberos = false; };

      };

      packages.${system} = rec {
        node = evalConfig [ ./configuration.nix ];
        toplevel = node.config.system.build.toplevel;
        run-node-vm = node.config.system.build.runvm;
      };
      defaultPackage.${system} = self.packages.${system}.run-node-vm;

      nixosModules = {};
    };
}
