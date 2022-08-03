{ pkgs, inputs, ... }: {
  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    registry.nixpkgs.flake = inputs.nixpkgs;
    registry.config.flake = inputs.self;
    package = pkgs.nix;
    extraOptions = "experimental-features = nix-command flakes";
  };
}
