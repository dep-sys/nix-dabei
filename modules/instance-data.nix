{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.x.instance-data;

  # Look for json-serialized instance data at `path` and load it if it exists.
  maybeGetInstanceData = path:
    if builtins.pathExists path
    then builtins.fromJSON (builtins.readFile path)
    else null;

  providers = {
    hcloud = {
      description = "hetzner.cloud, see https://docs.hetzner.cloud/#server-metadata";
      fetchInstanceData = pkgs.writeShellScriptBin "fetch-instance-data-hetzner.sh" ''
          for i in {1..10};
          do
              # wait until network is actually up
              if ${pkgs.curl}/bin/curl -s http://169.254.169.254; then
                break
              fi
          done

          ${pkgs.curl}/bin/curl http://169.254.169.254/hetzner/v1/metadata \
          | ${pkgs.yq}/bin/yq '.' \
          | tee ${cfg.path}
      '';
    };
  };
in {
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
      description = lib.mdDoc "Whether re-fetch instance-data on startup, even if `instance-data.path` already exists.";
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
      default =
        if cfg.rebuildOnChange
        then true
        else false;
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
        then maybeGetInstanceData ./foo # TODO make host-specific
        else maybeGetInstanceData cfg.path;
    };
  };

  config = let
    services = {
      make = input:
        lib.foldr lib.recursiveUpdate (lib.filterAttrs (n: v: n != "mixins") input) input.mixins;
      mixins = {
        # TODO check if https://github.com/NixOS/nixpkgs/blob/nixos-22.05/nixos/modules/security/systemd-confinement.nix
        # is an alternative
        #isIsolated = {
        #  serviceConfig = {
        #    TemporaryFileSystem = "/";
        #  };
        #};
        isOneShot = {
          restartIfChanged = false;
          unitConfig.X-StopOnRemoval = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
        neededByMultiUser = {
          wantedBy = ["multi-user.target"];
        };
        needsNetworking = {
          # We need to have *some* network connection atm to reach hetzners metadata server.
          # DHCP works well enough for the moment.
          requires = ["network-online.target"];
        };
        needsPath = path: {serviceConfig.ConditionPathExists = path;};
        #writesPath = path: {serviceConfig.BindPaths = path; };
        #readsPath = path: {serviceConfig.BindReadOnlyPaths = path; };
      };
    };
  in
    lib.mkMerge [
      ## Shared logic
      (lib.mkIf cfg.enable {
        systemd.paths = {
          # name of the path unit needs to match the service unit it should trigger
          rebuild-with-instance-data = {
            wantedBy = ["multi-user.target"];
            pathConfig = {
              PathExists = cfg.path;
              PathChanged = cfg.path;
            };
          };
        };
        systemd.services = {
          fetch-instance-data = services.make {
            description = "Fetch instance data from ${cfg.provider} on startup";
            script = "${providers.${cfg.provider}.fetchInstanceData}/bin/fetch-instance-data-hetzner.sh";
            mixins = with services.mixins; [
              isOneShot
              #isIsolated
              neededByMultiUser
              needsNetworking
              (needsPath (
                if cfg.onlyOnce
                then "!${cfg.path}"
                else null
              ))
              #(writesPath cfg.path)
            ];
          };
          rebuild-with-instance-data = services.make {
            description = "Rebuild the host with live-instance data from ${cfg.provider} on startup";
            path = with pkgs; [jq nettools nixos-rebuild];
            script = ''
              host_name=$(jq -r .hostname ${cfg.path} 2>/dev/null || echo "default")
              ${lib.optionalString cfg.onlyOnce ''
                if [ "$(hostname)" == "$host_name" ]
                then
                  echo "Hostname matches instance-data, host might already have been configured. Exiting."
                  exit 0
                fi
                echo "Setting up $host_name"
              ''}
              nixos-rebuild \
                  switch \
                  ${lib.optionalString cfg.upgradeOnChange "--upgrade"} \
                  --impure \
                  --flake \
                  "config#$host_name"
            '';
            mixins = with services.mixins; [
              isOneShot
              needsNetworking
              (needsPath cfg.path)
              #(readsPath cfg.path)
            ];
          };
        };
      })

      ## hcloud support
      (lib.mkIf (cfg.enable && cfg.provider == "hcloud" && cfg.data != null) {
        users.motd = with cfg.data; lib.mkDefault "Welcome to ${hostname} (#${builtins.toString instance-id}) in ${availability-zone} (${region}).";

        networking = let
          ipv6Config = lib.filter (v: v ? ipv6 && v.ipv6) (lib.head cfg.data.network-config.config).subnets;
          ipv6AddressParts = lib.splitString ipv6Config.address;
          interface = "ens3"; # TODO: continue to use predictable interfaces or use eth0 from json here?
        in {
          hostName = lib.mkDefault cfg.data.hostname;
          interfaces.${interface}.ipv6.addresses = [
            {
              address = builtins.elemAt ipv6AddressParts 0;
              prefixLength = lib.toInt (builtins.elemAt ipv6AddressParts 1);
            }
          ];
          defaultGateway6 = {
            inherit interface;
            address = ipv6Config.gateway;
          };
        };
      })
    ];
}
