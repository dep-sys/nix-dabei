{ pkgs, config, lib, ... }:

with lib;

{
  options.not-os = {
    nix = mkOption {
      type = types.bool;
      description = "Enable nix-daemon and a writeable store.";
    };
    simpleStaticIp = mkOption {
      type = types.bool;
      default = false;
      description = "set a static ip of 10.0.2.15";
    };
    preMount = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell commands to execute in stage-1, before root file system is mounted.
        Useful for debugging.'';
    };
  };
  config = {
    environment.systemPackages = lib.optional config.not-os.nix pkgs.nix;
    boot.kernelParams = [ "systemConfig=${config.system.build.toplevel}" ];
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;

    system.build.runvm = pkgs.writeScript "runner" ''
      #!${pkgs.stdenv.shell}
      exec ${pkgs.qemu_kvm}/bin/qemu-kvm -name not-os -m 512 \
        -drive index=0,id=drive1,file=${config.system.build.squashfs},readonly,media=cdrom,format=raw,if=virtio \
        -kernel ${config.system.build.kernel}/bzImage -initrd ${config.system.build.initialRamdisk}/initrd -nographic \
        -append "console=ttyS0 ${toString config.boot.kernelParams} quiet panic=-1" -no-reboot \
        -net nic,model=virtio \
        -net user,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,hostfwd=tcp::2222-:22 \
        -device virtio-rng-pci
    '';

    system.build.dist = pkgs.runCommand "not-os-dist" {} ''
      mkdir $out
      cp ${config.system.build.squashfs} $out/root.squashfs
      cp ${config.system.build.kernel}/*Image $out/kernel
      cp ${config.system.build.initialRamdisk}/initrd $out/initrd
      echo "${builtins.unsafeDiscardStringContext (toString config.boot.kernelParams)}" > $out/command-line
    '';

    # nix-build -A system.build.toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
    system.build.toplevel = pkgs.runCommand "not-os" {
      activationScript = config.system.activationScripts.script;
    } ''
      mkdir $out
      cp ${config.system.build.bootStage2} $out/init
      substituteInPlace $out/init --subst-var-by systemConfig $out
      ln -s ${config.system.path} $out/sw
      echo "$activationScript" > $out/activate
      substituteInPlace $out/activate --subst-var out
      chmod u+x $out/activate
      unset activationScript
    '';
    # nix-build -A squashfs && ls -lLh result
    system.build.squashfs = pkgs.callPackage (pkgs.path + "/nixos/lib/make-squashfs.nix") {
      storeContents = [ config.system.build.toplevel ];
    };

    system.activationScripts.ssh_keys = ''
      mkdir -p /etc/ssh
      test -f /etc/ssh/ssh_host_rsa_key || ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
      test -f /etc/ssh/ssh_host_ed25519_key || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
    '';
  };
}
