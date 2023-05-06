{
  self,
  lib,
  inputs,
  ...
} @ flake: {
  flake = {
    nixosModules = {
      build = import ./build.nix;
      module = import ./module.nix;
    };
  };
}
