{ pkgs, lib, nixosModules }: pkgs.nixosTest {
  name = "nix-dabei-ssh";
  meta.maintainers = [ lib.maintainers.phaer ];

  nodes = with lib; {
    server = { config, ... }: {
      imports = [./configuration.nix nixosModules.base nixosModules.build nixosModules.initrd];

      networking.hostName = lib.mkForce "server";
      boot.kernelParams = [
        "ip=${config.networking.primaryIPAddress}:::255.255.255.0::eth1:none"
      ];
      boot.initrd.network = {
        enable = true;
        ssh = {
          enable = true;
          authorizedKeys = [ (readFile ./initrd-network-ssh/id_ed25519.pub) ];
          port = 22;
          hostKeys = [ ./initrd-network-ssh/ssh_host_ed25519_key ];
        };
      };
      boot.initrd.systemd = {
        enable = true;
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

    client = { config, ... }: {
      environment.etc = {
        knownHosts = {
          text = concatStrings [
            "server,"
            "${
              toString (head (splitString " " (toString
                (elemAt (splitString "\n" config.networking.extraHosts) 2))))
            } "
            "${readFile ./initrd-network-ssh/ssh_host_ed25519_key.pub}"
          ];
        };
        sshKey = {
          source = ./initrd-network-ssh/id_ed25519;
          mode = "0600";
        };
      };
    };
  };

  testScript = ''
    start_all()
    client.wait_for_unit("network.target")


    def ssh_is_up(_) -> bool:
        status, _ = client.execute("nc -z server 22")
        return status == 0


    with client.nested("waiting for SSH server to come up"):
        retry(ssh_is_up)


    client.succeed(
        "echo foo | ssh -i /etc/sshKey -o UserKnownHostsFile=/etc/knownHosts server 'systemd-tty-ask-password-agent'"
    )
    server.wait_for_unit("sysinit.target")
  '';
}
