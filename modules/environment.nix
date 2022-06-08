{ config, lib, pkgs, ... }:
{
  config = {
    environment.systemPackages = with pkgs; [ utillinux coreutils iproute iputils procps bashInteractive runit gitMicro curl ];
    environment.pathsToLink = [ "/bin" ];
    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
    };
    environment.etc = {
      "nix/nix.conf".source = pkgs.runCommand "nix.conf" {} ''
        extraPaths=$(for i in $(cat ${pkgs.writeReferencesToFile pkgs.stdenv.shell}); do if test -d $i; then echo $i; fi; done)
        cat > $out << EOF
        build-use-sandbox = true
        build-users-group = nixbld
        build-sandbox-paths = /bin/sh=${pkgs.stdenv.shell} $(echo $extraPaths)
        experimental-features = nix-command flakes
        EOF
      '';
      bashrc.text = "export PATH=/run/current-system/sw/bin";
      profile.text = "export PATH=/run/current-system/sw/bin";
      "resolv.conf".text = "nameserver 10.0.2.3";
      passwd.text = ''
        root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
        sshd:x:999:998:SSH privilege separation user:/var/empty:/run/current-system/sw/bin/nologin
        nixbld1:x:30001:30000:Nix build user 1:/var/empty:/run/current-system/sw/bin/nologin
        nixbld2:x:30002:30000:Nix build user 2:/var/empty:/run/current-system/sw/bin/nologin
        nixbld3:x:30003:30000:Nix build user 3:/var/empty:/run/current-system/sw/bin/nologin
        nixbld4:x:30004:30000:Nix build user 4:/var/empty:/run/current-system/sw/bin/nologin
        nixbld5:x:30005:30000:Nix build user 5:/var/empty:/run/current-system/sw/bin/nologin
        nixbld6:x:30006:30000:Nix build user 6:/var/empty:/run/current-system/sw/bin/nologin
        nixbld7:x:30007:30000:Nix build user 7:/var/empty:/run/current-system/sw/bin/nologin
        nixbld8:x:30008:30000:Nix build user 8:/var/empty:/run/current-system/sw/bin/nologin
        nixbld9:x:30009:30000:Nix build user 9:/var/empty:/run/current-system/sw/bin/nologin
        nixbld10:x:30010:30000:Nix build user 10:/var/empty:/run/current-system/sw/bin/nologin
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
