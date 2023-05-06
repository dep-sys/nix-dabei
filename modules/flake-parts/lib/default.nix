{
  self,
  lib,
  inputs,
  ...
} @ flake: {
  flake.lib = {
    makeInstaller = modules:
      inputs.nixpkgs.lib.nixosSystem {
        modules = (builtins.attrValues self.nixosModules) ++ modules;
      };
  };
}
