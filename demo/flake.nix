{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dabei.url = "github:dep-sys/nix-dabei/auto-installer";
    colmena.url = "github:zhaofengli/colmena/main";
  };

  # If you get a warning that this is ignored, it might be
  # due to your user not being in trusted-users. See
  # https://github.com/NixOS/nix/issues/6672
  nixConfig.extra-substituters = [ "https://colmena.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg=" ];

  outputs = { self, nixpkgs, nix-dabei, colmena, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    sshKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLopgIL2JS/XtosC8K+qQ1ZwkOe1gFi8w2i1cd13UehWwkxeguU6r26VpcGn8gfh6lVbxf22Z9T2Le8loYAhxANaPghvAOqYQH/PJPRztdimhkj2h7SNjP1/cuwlQYuxr/zEy43j0kK0flieKWirzQwH4kNXWrscHgerHOMVuQtTJ4Ryq4GIIxSg17VVTA89tcywGCL+3Nk4URe5x92fb8T2ZEk8T9p1eSUL+E72m7W7vjExpx1PLHgfSUYIkSGBr8bSWf3O1PW6EuOgwBGidOME4Y7xNgWxSB/vgyHx3/3q5ThH0b8Gb3qsWdN22ZILRAeui2VhtdUZeuf2JYYh8L"
    ];
    bootDisk = "/dev/sda";
  in {
    apps.${system} = {
      colmena = colmena.apps.${system}.default;
    };

    nixosConfigurations = self.colmenaHive.nodes;
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = pkgs;
      };

      web-01 = { name, nodes, pkgs, lib, config, modulesPath, ... }: {
        imports = [
          "${modulesPath}/profiles/qemu-guest.nix"
          nix-dabei.inputs.disko.nixosModules.disko
        ];

        config = {
          deployment = {
            targetHost = "${name}.${config.my.domain}";
            targetPort = 22;
            targetUser = "root";
            buildOnTarget = true;
          };

          disko.devices = nix-dabei.diskoConfigurations.zfs-simple { diskDevice = bootDisk; };
          boot.loader.grub = {
            enable = true;
            devices = [ bootDisk ];
          };

          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };

          time.timeZone = "UTC";
          system.stateVersion = "22.11";
          users.users.root.openssh.authorizedKeys.keys = sshKeys;

          networking.hostName = "${name}";
          networking.hostId = builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName);
          networking.interfaces.eth0.useDHCP = true;

          environment.systemPackages = with pkgs; [
            vim tmux htop ncdu fd ripgrep fzf jq
          ];
          nix.extraOptions = "experimental-features = nix-command flakes";
        };
      };
    };
  };
}
