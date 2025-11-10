{
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs {}
}:
let
  inherit (pkgs) lib;

  shell = pkgs.mkShell {
    name = "nix-dabei";
    packages = [
      pkgs.nix-tree
    ];
  };

  modules = {
    mini = {
      boot.loader.grub.enable = false;
      boot.initrd.systemd.enable = true;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      system.stateVersion = "25.11";
    };

    no-switch = {
      boot.initrd.systemd = {
        targets.initrd-switch-root.enable = true;
        services.initrd-switch-root.enable = true;
        services.initrd-cleanup.enable = true;
        services.initrd-parse-etc.enable = false;
        services.initrd-nixos-activation.enable = false;
        services.initrd-find-nixos-closure.enable = false;
      };
    };

    vm = {
      virtualisation.vmVariant.virtualisation = {
        cores = 8;
        memorySize = 1024 * 8;
        graphics = false;
        fileSystems = lib.mkForce {};
        diskImage = lib.mkForce null;
      };
    };

    debug = {
      boot.kernelParams = [
        "rd.systemd.debug_shell=ttyS0"
      ];

      boot.initrd.systemd = {
        emergencyAccess = true;

        initrdBin = [
          pkgs.gnugrep
          pkgs.gawk
          pkgs.helix
          pkgs.rsync
        ];

        services."switch-to-tmpfs" = {
          description = "Copy initrd to tmpfs sysroot";
          after = [ "sysroot.mount" ];
          before = [ "initrd-switch-root.target" ];
          requiredBy = [ "initrd-switch-root.target" ];
          wantedBy = [ "initrd.target" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            rsync -avz / /sysroot/ --exclude=/sysroot -x
          '';
        };
      };
    };

    network = {
      boot.initrd.systemd = {
        initrdBin = [
          pkgs.iputils
          pkgs.iproute2
        ];
        network = {
          enable = true;
          networks."10-default" = {
            enable = true;
            matchConfig.Name = "en*";
            DHCP = "yes";
          };
        };
        # remove initrd-switch-root.target conflict
        services.systemd-resolved.unitConfig.Conflicts = [ "" ];
        services.systemd-networkd.unitConfig.Conflicts = [ "" ];
        contents = let
          caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        in {
          "/etc/ssl/certs/ca-bundle.crt".source = caBundle;
          "/etc/ssl/certs/ca-certificates.crt".source = caBundle;
        };
      };
    };

    nix = {config, ...}: let
      bldUsers = lib.map (n: "nixbld${toString n}") (lib.range 1 10);
    in {
      boot.initrd.systemd = {
        users = lib.genAttrs
          bldUsers
          (n: {group = "nixbld"; });
        groups.nixbld = { };
        initrdBin = [ pkgs.nixStatic ];
        contents."/etc/group".text =
          lib.mkForce ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (n: { gid }: "${n}:x:${toString gid}:${lib.optionalString (n == "nixbld") (lib.concatStringsSep "," bldUsers)}") config.boot.initrd.systemd.groups
            )}
          '';

        contents."/etc/nix/nix.conf".text = ''
          experimental-features = nix-command flakes auto-allocate-uids
        '';
      };
    };
  };

  nixos = pkgs.nixos {
    imports = [
      modules.mini
      modules.no-switch
      modules.vm
      modules.debug
      modules.network
      modules.nix
    ];
  };

  inherit (nixos) vm;

in
 {
   inherit shell nixos vm pkgs lib;
 }
