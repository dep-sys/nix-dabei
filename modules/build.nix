{ pkgs, config, lib, ... }:
with lib;
{
  config = let
    kernelParams = builtins.unsafeDiscardStringContext (toString config.boot.kernelParams);
    kernelFile = config.system.boot.loader.kernelFile;
    kernel = "${config.system.build.kernel}/${kernelFile}";
    initrd = "${config.system.build.initialRamdisk}/initrd";
    toplevel = config.system.build.toplevel;
    in {

    system.build.runvm = pkgs.writeShellScript "runner" ''
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name nix-dabei -m 2048 \
        -kernel ${kernel} -initrd ${initrd} -nographic \
        -append "console=ttyS0 init=${pkgs.bash}/bin/bash ${kernelParams} " -no-reboot \
        -net nic,model=virtio \
        -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        -device virtio-rng-pci
    '';
    };
}
