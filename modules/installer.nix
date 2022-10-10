{ config, pkgs, lib, ... }:
{
  options = {
    #networking.primaryIPAddress = lib.mkOption {
    #  default = "10.0.2.2";
    #  type = lib.types.str;
    #};
  };

  config = {
    boot.kernelParams = [
      "ip=dhcp"
      #"ip=${config.networking.primaryIPAddress}:::255.255.255.0::eth0:none"
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
