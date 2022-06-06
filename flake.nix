{
  description = "An optionated nixos installer";
  inputs.nixpkgs.url = "nixpkgs/nixos-22.05";

  outputs = { self, nixpkgs }@inputs:
    let
      # System types to support.
      system = "x86_64-linux";
      # Nixpkgs instantiated for supported system types.
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
    in {
      overlay = final: prev: {
        kexec = prev.callPackage ./kexec.nix {
          inherit nixpkgs system;
          inherit (self.nixosModules) installer;
        };
      };

      packages.${system} =
        {
          inherit (pkgs) kexec;
        };
      defaultPackage.${system} = self.packages.${system}.kexec;

      nixosModules = {
        #zfs = import ./modules/zfs.nix;
        #hetzner = import ./modules/hetzner.nix;

        core = { pkgs, lib, ... }: {
          i18n.defaultLocale = "en_US.UTF-8";
          time.timeZone = "UTC";
          networking = {
            firewall.allowedTCPPorts = [ 22 ];
            usePredictableInterfaceNames = true;
            useDHCP = true;
          };
          environment.systemPackages = [
            pkgs.gitMinimal  # de facto needed to work with flakes
          ];

          services.openssh = {
            enable = true;
            passwordAuthentication = lib.mkForce false;
            permitRootLogin = lib.mkForce "without-password";
          };

          boot.initrd.systemd = {
            enable = true;
            emergencyAccess = true;
          };
        };

        nix = { pkgs, lib, ... }: {
          config = {
            nix = {
              nixPath = [ "nixpkgs=${nixpkgs}" ];
              registry.nixpkgs.flake = nixpkgs;
              #registry.installer.flake = self;
              extraOptions = "experimental-features = nix-command flakes";
            };
            nixpkgs.overlays = [ self.overlay ];
          };
        };

        installer =
          { pkgs, lib, ... }:
          {
            imports = with self.nixosModules; [
              core nix
            ];

            config =
              {
                system.stateVersion = "22.05";
                users.extraUsers.root.password = "testtest";

                system.build.bootStage2 = let
                  bootStage2 = pkgs.substituteAll {
                    src = ./stage-2.sh;
                    shell = "${pkgs.bash}/bin/bash";
                    path = lib.makeBinPath ([
                      pkgs.coreutils
                      pkgs.util-linux
                    ]);
                  };
                in lib.mkForce bootStage2;
              };
          };
      };
    };
}
