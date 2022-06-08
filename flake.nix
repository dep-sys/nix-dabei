{
  description = "Minimal operating systems based on not-os";
  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
      lib = nixpkgs.lib;
      baseModules = builtins.attrValues self.nixosModules;

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
        gitMicro = (prev.gitMinimal.override {
          perlSupport = false;
          withManual = false;
          pythonSupport = false;
          withpcre2 = false;
        }).overrideAttrs (oldAttrs: { doInstallCheck = false; });
      };

      packages.${system} = let
        config = (evalConfig [ ./configuration.nix ]).config;
      in {
        inherit (config.system.build) runvm dist toplevel squashfs;
      };
      defaultPackage.${system} = self.packages.${system}.runvm;

      nixosModules = {
        environment = ./modules/environment.nix;
        base = ./modules/base.nix;
        runit = ./modules/runit.nix;
        stage-1 = ./modules/stage-1.nix;
        stage-2 = ./modules/stage-2.nix;
        compat = ./modules/compat.nix;
        upstream = {
          imports = [
            "${nixpkgs}/nixos/modules/system/etc/etc-activation.nix"
            "${nixpkgs}/nixos/modules/system/activation/activation-script.nix"
            "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
            "${nixpkgs}/nixos/modules/system/boot/kernel.nix"
            "${nixpkgs}/nixos/modules/misc/assertions.nix"
            "${nixpkgs}/nixos/modules/misc/lib.nix"
            "${nixpkgs}/nixos/modules/config/sysctl.nix"
            "${nixpkgs}/nixos/modules/security/ca.nix"
          ];
        };
        nixpkgs = {
          config.nixpkgs = {
            inherit pkgs;
            localSystem = { inherit system; };
          };
        };
      };
    };
}
