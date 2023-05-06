{
  self,
  lib,
  inputs,
  ...
} @ flake: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,

    # this is our buildPlatform
    system,
    ...
  }: let

    # For some platforms which have native artifacts cached on cache.nixos.org
    #   we substitute some paths from the cache instead of cross compiling.
    cachedPlatforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    # For the current buildPlatform (the current system coming from perSystem),
    #   this generates cross compiled outputs for all other systems that
    #   that the flake produces outputs for.
    packagesForPlatform = hostPlatform: let
      machine = machineForPlatform hostPlatform;
      suffix =
        if system == hostPlatform
        then ""
        else "-${hostPlatform}";
    in {
      "kexec${suffix}" = machine.config.system.build.kexec;
      "kexecTarball${suffix}" = machine.config.system.build.kexecTarball;
      "vm${suffix}" = machine.config.system.build.vm;
    };

    # Modify the nixosConfiguration.default to target a certain hostPlatform.
    # This sets up the machine for cross compilation.
    machineForPlatform = hostPlatform:
      self.nixosConfigurations.default.extendModules {
        modules = [(
          {
            nixpkgs.hostPlatform = hostPlatform;
            nixpkgs.buildPlatform = system;
            nixpkgs.overlays = [(overlaysForPlatform hostPlatform)];
          }
        )];
      };

    # get some native artifacts from cache.nixos.org instead of cross building.
    overlaysForPlatform = hostPlatform: let
      nativePkgs = inputs.nixpkgs.legacyPackages.${hostPlatform};
    in curr: prev:
      if ! lib.elem hostPlatform cachedPlatforms
      then {}
      else {
        nix = nativePkgs.nix;
        nixos-isntall-tools = nativePkgs.nixos-install-tools;
        zfs = nativePkgs.zfs;
        rsync = nativePkgs.rsync;
        parted = nativePkgs.parted;
        openssh = nativePkgs.openssh;
      };

  in {
    # merge all packages generated via the functions above.
    packages = lib.foldl (a: b: a // b) {}
      (map packagesForPlatform flake.config.systems);
  };
}
