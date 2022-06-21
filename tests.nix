{ pkgs, nixosModules }:
let
  mkTest = testScript:
    pkgs.nixosTest {
      inherit testScript;
      nodes = {
        node1 = { config, lib, nodes, pkgs, ... }: {
          imports = [
            ./configuration.nix
            ./modules/base.nix
            ./modules/build.nix
          ];# ++ pkgs.lib.attrValues nixosModules;  # TODO find out why this causes infinite recursion
          config = {
            networking.hostName = lib.mkForce "node1";
            networking.usePredictableInterfaceNames = lib.mkForce false;
          };
        };
        node2 = { config, lib, nodes, pkgs, ... }: {
          imports = [
            ./configuration.nix
            ./modules/base.nix
            ./modules/build.nix
          ];
          config = {
            networking.hostName = lib.mkForce "node2";
            networking.usePredictableInterfaceNames = lib.mkForce false;
            environment.systemPackages = [ pkgs.hello ];
          };
        };
      };
  };
in mkTest
    ({ nodes }: ''
      start_all()

      with subtest("handover to stage-2 systemd works"):
          node1.wait_for_unit("multi-user.target")
          #node1.succeed("systemd-analyze | grep -q '(initrd)'")  # direct handover
          node1.succeed("touch /testfile")  # / is writable
          node1.fail("touch /nix/store/testfile")  # /nix/store is not writable
          # Special filesystems are mounted by systemd
          node1.succeed("[ -e /run/booted-system ]") # /run
          node1.succeed("[ -e /sys/class ]") # /sys
          node1.succeed("[ -e /dev/null ]") # /dev
          node1.succeed("[ -e /proc/1 ]") # /proc
          # stage-2-init mounted more special filesystems
          node1.succeed("[ -e /dev/shm ]") # /dev/shm
          node1.succeed("[ -e /dev/pts/ptmx ]") # /dev/pts
          node1.succeed("[ -e /run/keys ]") # /run/keys

      with subtest("kexec works"):
          # Test whether reboot via kexec works.
          node1.wait_for_unit("multi-user.target")
          node1.succeed('kexec --load /run/current-system/kernel --initrd /run/current-system/initrd --command-line "$(</proc/cmdline)"')
          node1.execute("systemctl kexec >&2 &", check_return=False)
          node1.connected = False
          node1.connect()
          node1.wait_for_unit("multi-user.target")

          node2.wait_for_unit("multi-user.target")
          node2.shutdown()

          # Kexec node1 to the toplevel of node2 via the kexec-boot script
          node1.succeed('touch /run/foo')
          node1.fail('hello')
          node1.execute('${nodes.node2.config.system.build.dist}/kexec-boot', check_return=False)
          node1.succeed('! test -e /run/foo')
          node1.succeed('hello')
          node1.succeed('[ "$(hostname)" = "node2" ]')

          node1.shutdown()
    '')
