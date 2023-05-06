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
    system,
    ...
  }: {
    packages = let
      config = self.nixosConfigurations.default.config;
    in {
      inherit (config.system.build)
        kexec
        kexecTarball
        vm;
      default = config.system.build.kexec;
    };
  };
}
