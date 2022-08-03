{ pkgs, lib, config, inputs, ... }: {
  imports = [ ./nix.nix ];

  options.x = {
    toml = lib.mkOption {
      description = "read site-specific info from toml";
      readOnly = true;
      default = let
        configPath = "${inputs.self.outPath}/config.toml";
        in
          assert (builtins.pathExists configPath);
          lib.importTOML "${inputs.self.outPath}/config.toml";
    };

    admins = lib.mkOption {
      description = "Attrset of admin username and ssh keys";
      type = lib.types.attrsOf (lib.types.listOf lib.types.string);
      default = config.x.toml.admins;
    };

    boot.efi = lib.mkEnableOption {
      description = "Whether the target system boots via EFI or legacy boot";
      default = false;
    };

    storage.zfs.enable = lib.mkEnableOption {
      description = "Whether this system uses openzfs.org";
      default = true;
    };
  };

  config = {
    # Let 'nixos-version --json' know about the Git revision of this flake.
    system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;
    system.stateVersion = lib.mkDefault "22.05";

    users = {
      mutableUsers = lib.mkDefault false;
      users = {
        root = {
          isSystemUser = true;
          openssh.authorizedKeys.keys = lib.flatten (lib.attrValues config.x.admins);
        };
      } // (
        lib.mapAttrs (n: v: {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = v;
        }) config.x.admins
      );
    };

    i18n.defaultLocale = "en_US.UTF-8";
    time.timeZone = "UTC";
    boot.cleanTmpDir = true;

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
      permitRootLogin = "without-password";
    };

    # Network configuration.
    networking.useDHCP = true;
    networking.firewall.allowedTCPPorts = [ 22 ];

    # Shell environment
    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
    environment.systemPackages = with pkgs; [
      vim tmux htop ncdu curl dnsutils jq fd ripgrep gawk gnused git
    ];
  };
}
