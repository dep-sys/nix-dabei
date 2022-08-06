{ config, pkgs, lib, ... }:
let
  cfg = config.x.instance-data;

  # Look for json-serialized instance data at `path` and load it if it exists.
  maybeGetInstanceData = path:
    if builtins.pathExists path
    then builtins.fromJSON (builtins.readFile path)
    else null;

  providers = {
    hcloud = {
      description = "hetzner.cloud, see https://docs.hetzner.cloud/#server-metadata";
      fetchInstanceData = pkgs.writeShellScript "fetch-instance-data-hetzner" ''
          ${pkgs.curl}/bin/curl -s http://169.254.169.254/hetzner/v1/metadata/ \
          ${pkgs.yq}/bin/yq '.' \
          > ${cfg.path}
      '';
    };
  };
in
{
  options.x.instance-data = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = lib.mdDoc "Whether to fetch instance-data from a cloud provider on startup.";
      default = true;
    };

    provider = lib.mkOption {
      type = lib.types.enum (lib.attrNames providers);
      description = lib.mdDoc "Whether to fetch instance-data from a cloud provider on startup.";
      default = "hcloud";
    };

    onlyOnce = lib.mkOption {
      type = lib.types.bool;
      description = lib.mdDoc "Whether re-fetch instance-data on startup, even if `instance-data.path` alreadz exists.";
      default = true;
    };

    path = lib.mkOption {
      type = lib.types.path;
      description = lib.mdDoc "path to store instance-data at.";
      default = "/var/run/instance-data.json";
    };

    rebuildOnChange = lib.mkOption {
      type = lib.types.bool;
      description = lib.mdDoc "Whether to rebuild the system whenever `instance-data.path` changes.";
      default = true;
    };

    upgradeOnChange = lib.mkOption {
      type = lib.types.bool;
      description = lib.mdDoc "Whether to upgrade the system whenever we rebuild it.";
      default = if cfg.rebuildOnChange then true else false;
    };

    data = lib.mkOption {
      type = lib.types.anything;
      description = lib.mdDoc ''
          instance data as fetched from a cloud-provider and stored at `instance-data.path`, deserialized.
      '';
      default =
        # Look for commited instance-data inside our flake in pure mode, and outside at `cfg.path` in impure
        # mode. Give up and return `null` if neither is found.
        if lib.inPureEvalMode
        then maybeGetInstanceData ./foo
        else maybeGetInstanceData cfg.path;
    };
  };


  config =
    lib.mkMerge [

      ## Shared logic
      (lib.mkIf (cfg.enable) {
        systemd.services.fetch-instance-data = {
          script = builtins.toString providers.${cfg.provider}.fetchInstanceData;
          description = "Fetch instance data from ${cfg.provider} on startup";

          wantedBy = [ "multi-user.target" ];
          after = [ "multi-user.target" ];
          # We need to have *some* network connection atm to reach hetzners metadata server.
          # DHCP works well enough for the moment.
          requires = [ "network-online.target" ];

          restartIfChanged = false;
          unitConfig.X-StopOnRemoval = false;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TemporaryFileSystem = "/";
            BindPaths = cfg.path;
            ConditionPathExists = if cfg.onlyOnce then "!${cfg.path}" else null;
          };
        };
      })

      ## hcloud support
      (lib.mkIf (cfg.enable && cfg.provider == "hcloud" && cfg.data != null) {
        networking.hostName = lib.mkDefault cfg.data.hostname;
      })
    ];
}