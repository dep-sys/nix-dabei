{ config, lib, pkgs, ... }:

# based heavily on https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/system-path.nix

with lib;

let
  requiredPackages = with pkgs; [ utillinux coreutils iproute iputils procps bash runit gitMicro curl ];
  # curl gitMinimal bashInteractive
in
{
  options = {
  };
  config = {
    environment.systemPackages = requiredPackages;
    environment.pathsToLink = [ "/bin" ];
    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
    };
  };
}
