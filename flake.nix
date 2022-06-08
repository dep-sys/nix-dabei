{
  description = "An operating system generator, based on not-os, focused on installation";
  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
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

      lib.makeDocs = import ./lib/makeDocs.nix;

      packages.${system} =
        with pkgs;
        let
          nixosConfiguration = lib.evalModules {
            modules = [ ./configuration.nix ] ++ lib.attrValues self.nixosModules;
          };

          docs = self.lib.makeDocs {
            inherit pkgs;
            modules = (builtins.attrValues self.nixosModules);
            # Only document options which are declared inside this flake.
            filter = (name: opt: lib.any (d: lib.hasPrefix "${self}/modules/" d) opt.declarations);
        };
      in {
        inherit (nixosConfiguration.config.system.build) runvm dist toplevel squashfs;
        # TODO: app for `cp -L --no-preserve=mode result/options.md options.md`
        docs = docs.all;
      };
      defaultPackage.${system} = self.packages.${system}.runvm;


      nixosModules = {
        environment = ./modules/environment.nix;
        base = ./modules/base.nix;
        runit = ./modules/runit.nix;
        stage-1 = ./modules/stage-1.nix;
        stage-2 = ./modules/stage-2.nix;
        # Extracted nixos options shims, where we don't want the whole nixos module file.
        compat = ./modules/compat.nix;
        # NixOS modules which can be re-used as-is.
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
