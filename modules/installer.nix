{ config, pkgs, lib, disko, ... }:
let
  diskConfig = {
    disk = {
      vda = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "boot";
              type = "partition";
              start = "0";
              end = "1M";
              part-type = "primary";
              flags = ["bios_grub"];
            }
            {
              type = "partition";
              name = "ESP";
              start = "1M";
              end = "256M";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            {
              type = "partition";
              name = "zfs";
              start = "256M";
              end = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            }
          ];
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        mode = "";
        rootFsOptions = {
          compression = "zstd";
        };
        datasets = {
          "root" = {
             zfs_type = "filesystem";
             mountpoint = "/";
          };
          "nix" = {
             zfs_type = "filesystem";
             mountpoint = "/nix";
          };
          "home" = {
             zfs_type = "filesystem";
             mountpoint = "/home";
          };
        };
      };
    };
  };
  in
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
      # Network is configured with kernelParams
      network.networks = { };

      extraBin = {
        nix = "${pkgs.nix}/bin/nix";
        nixos-install = "${pkgs.nixos-install-tools}/bin/nixos-install";
        parted = "${pkgs.parted}/bin/parted";
        jq = "${pkgs.jq}/bin/jq";
        tsp-create = pkgs.writeScript "tsp-create" (disko.create diskConfig);
        tsp-mount = pkgs.writeScript "tsp-mount" (disko.mount diskConfig);
      };

      # When these are enabled, they prevent useful output from
      # going to the console
      paths.systemd-ask-password-console.enable = false;
      services.systemd-ask-password-console.enable = false;

      services = {

        install-nixos = {
          requires = ["network-online.target"];
          after = ["network-online.target"];
          requiredBy = [ "initrd-switch-root.service" ];
          before = [ "initrd-switch-root.service" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
               nixos-install \
               --root /mnt \
               --no-root-passwd \
               --flake github:dep-sys/nix-dabei/kexec#default
          '';
        };

        format-disk = {
          requires = [ "systemd-udevd.service"];
          after = [ "systemd-udevd.service"];
          requiredBy = [ "install-nixos.service" ];
          before = [ "install-nixos.service" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            udevadm trigger --subsystem-match=block; udevadm settle
            ${disko.create diskConfig}
            ${disko.mount diskConfig}
          '';
        };
      };
    };
  };
}
