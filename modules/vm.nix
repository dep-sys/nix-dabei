{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
    "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
  ];

  services.getty.autologinUser = lib.mkDefault "root";
  boot.kernelParams = ["console=tty1" "console=ttyS0,115200"];
  virtualisation = {
    memorySize = 2048;
    forwardPorts = [
      {
        host.port = 2222;
        guest.port = 22;
      }
      {
        host.port = 8080;
        guest.port = 80;
      }
      {
        host.port = 8043;
        guest.port = 443;
      }
    ];
    qemu.options = [
      "-nographic"
    ];
  };
}
