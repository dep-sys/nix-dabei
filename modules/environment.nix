{ config, lib, pkgs, ... }:
{
  config = {
    environment.systemPackages = with pkgs; [
      utillinux
      coreutils
      iproute
      iputils
      procps
      bashInteractive
      runit
      gitMicro
      curl
    ];

    environment.pathsToLink = [ "/bin" "lib" ];
    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
    };
    environment.etc = {
      bashrc.text = "export PATH=/run/current-system/sw/bin";
      profile.text = "export PATH=/run/current-system/sw/bin";
      "resolv.conf".text = "nameserver 10.0.2.3";

      "ssh/sshd_config".text = ''
          Port 22
          Protocol 2
          HostKey /etc/ssh/ssh_host_rsa_key
          HostKey /etc/ssh/ssh_host_ed25519_key
          PidFile /run/sshd.pid
          PermitRootLogin without-password
          PasswordAuthentication no
          AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
      '';

      "nix/nix.conf".source = pkgs.runCommand "nix.conf" {} ''
        extraPaths=$(for i in $(cat ${pkgs.writeReferencesToFile pkgs.stdenv.shell}); do if test -d $i; then echo $i; fi; done)
        cat > $out << EOF
        build-use-sandbox = true
        build-users-group = nixbld
        build-sandbox-paths = /bin/sh=${pkgs.stdenv.shell} $(echo $extraPaths)
        experimental-features = nix-command flakes
        EOF
      '';

      passwd.text = let
        nixBuildUser = i: "nixbld${toString i}:x:3${lib.fixedWidthNumber 4 i}:30000:Nix build user ${toString i}:/var/empty:/run/current-system/sw/bin/nologin";
      in ''
        root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
        sshd:x:999:998:SSH privilege separation user:/var/empty:/run/current-system/sw/bin/nologin
        ${lib.concatMapStringsSep "\n" nixBuildUser (lib.range 1 10)}
      '';

      "nsswitch.conf".text = ''
        hosts:     files  dns   myhostname mymachines
        networks:  files dns
      '';

      "services".source = pkgs.iana-etc + "/etc/services";
      group.text = ''
        root:x:0:
        nixbld:x:30000:nixbld1,nixbld10,nixbld2,nixbld3,nixbld4,nixbld5,nixbld6,nixbld7,nixbld8,nixbld9
      '';
    };
  };
}
