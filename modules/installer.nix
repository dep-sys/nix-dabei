{ config, pkgs, lib, ... }:
{
  config = {
    boot.kernelParams = [
      "ip=dhcp"
    ];

    boot.initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        authorizedKeys = [ (lib.readFile ../initrd-network-ssh/id_ed25519.pub) ];
        port = 22;
        hostKeys = [ ../initrd-network-ssh/ssh_host_ed25519_key ];
      };
    };

    # Add libnss_dns, nameserver and certificates for outgoing https connections
    boot.initrd.environment.etc = {
      "resolv.conf".text = "nameserver 1.1.1.1";
      "ssl/certs/ca-certificates.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    boot.initrd.systemd.storePaths = [
      # so nix can look up dns entries
      "${pkgs.glibc}/lib/libnss_dns.so.2"
    ];



    boot.initrd.systemd = {
      extraBin.nix = "${pkgs.nix}/bin/nix";
      extraBin.nixos-install = "${pkgs.nixos-install-tools}/bin/nixos-install";
      # Network is configured with kernelParams
      network.networks = { };

      # When these are enabled, they prevent useful output from
      # going to the console
      paths.systemd-ask-password-console.enable = false;
      services.systemd-ask-password-console.enable = false;

      services.wait = {
        requiredBy = [ "initrd.target" ];
        before = [ "initrd.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
            exec test $(systemd-ask-password) = foo
          '';
      };
    };
  };
}
