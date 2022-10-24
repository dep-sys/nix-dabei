{ pkgs, system, self }:
let
  lib = pkgs.lib;
  baseConfig = self.lib.installerModules;
  mkTest = { name, nodes, testScript }:
    pkgs.nixosTest {
      inherit name nodes testScript;
      meta.maintainers = [ lib.maintainers.phaer ];
    };
in {
  test-ssh = mkTest {
    name = "ssh";
    nodes = with lib; {
      installer = { config, ... }: {
        imports = baseConfig;
        networking.hostName = lib.mkForce "installer";

        users.users.root.openssh.authorizedKeys.keys = mkForce [(readFile ./fixtures/id_ed25519.pub)];
        boot.kernelParams = [
          "ip=${config.networking.primaryIPAddress}:::255.255.255.0::eth1:none"
          "ssh_host_key=LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUFNd0FBQUF0emMyZ3RaVwpReU5UVXhPUUFBQUNEUDlNejZxbHhkUXFBNG9tcmdiT2xWc3hTR09OQ0pzdGpXOXpxcXVhamxJQUFBQUpnMFdHRkdORmhoClJnQUFBQXR6YzJndFpXUXlOVFV4T1FBQUFDRFA5TXo2cWx4ZFFxQTRvbXJnYk9sVnN4U0dPTkNKc3RqVzl6cXF1YWpsSUEKQUFBRUEwSGpzN0xmRlBkVGYzVGhHeDZHTkt2WDBJdGd6Z1hzOTFaM29HSWFGNlM4LzB6UHFxWEYxQ29EaWlhdUJzNlZXegpGSVk0MElteTJOYjNPcXE1cU9VZ0FBQUFFRzVwZUdKc1pFQnNiMk5oYkdodmMzUUJBZ01FQlE9PQotLS0tLUVORCBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K"
        ];
      };

      client = { config, ... }: {
        environment.etc = {
          knownHosts = {
            text = concatStrings [
              "installer,"
              "${
                toString (head (splitString " " (toString
                  (elemAt (splitString "\n" config.networking.extraHosts) 2))))
              } "
              "${readFile ./fixtures/ssh_host_ed25519_key.pub}"
            ];
          };
          sshKey = {
            source = ./fixtures/id_ed25519;
            mode = "0600";
          };
        };
      };
    };

    testScript = ''
    start_all()
    client.wait_for_unit("network.target")


    def ssh_is_up(_) -> bool:
        status, _ = client.execute("nc -z installer 22")
        return status == 0


    with client.nested("waiting for SSH server to come up"):
        retry(ssh_is_up)


    client.succeed(
        "ssh -i /etc/sshKey -o UserKnownHostsFile=/etc/knownHosts installer 'ls /sysroot'"
    )
  '';
  };

  test-kexec = mkTest {
    # TODO this test is currently broken as the test driver is seemingly unable to re-connect
    # to the console after switching kernels. This works manually though...
    name = "kexec";
    nodes = {
      target = {};
      installer =
        { config, ... }: {
          imports = baseConfig;
          networking.hostName = lib.mkForce "installer";
          boot.kernelParams = [
            "ip=${config.networking.primaryIPAddress}:::255.255.255.0::eth1:none"
          ];
        };
   };
    testScript = { nodes }: ''
      target.wait_for_unit("multi-user.target")

      # Kexec target to the toplevel of installer via the kexec-boot script
      target.succeed('touch /run/foo')
      target.fail('[ "$(hostname)" = "installer" ]')
      target.execute('${nodes.installer.system.build.kexec}/kexec-boot', check_return=False)
      target.wait_for_unit("initrd.target")
      target.succeed('! test -e /run/foo')
      target.succeed('test "$(cat /etc/hostname)" = "installer"')
      target.shutdown()
    '';
  };
}
