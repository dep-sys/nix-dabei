{
  self,
  lib,
  inputs,
  ...
} @ flake: {
  flake = {
    nixosConfigurations.default = self.lib.makeInstaller [
      "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
    ];
  };
}
