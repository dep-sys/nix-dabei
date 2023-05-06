{
  self,
  lib,
  inputs,
  ...
} @ flake: {
  flake.lib = {
    makeInstaller = modules: inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
      modules = (builtins.attrValues self.nixosModules) ++ modules;
    };
  };
}
