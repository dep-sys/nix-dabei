{ nixpkgs, system, self }:
let
  lib = nixpkgs.lib;
  extraConfigurations = [
    ./configuration.nix
    ({ networking.usePredictableInterfaceNames = lib.mkForce false; })
  ] ++ lib.attrValues self.nixosModules;
  testTools = import (nixpkgs + "/nixos/lib/testing-python.nix") { inherit system extraConfigurations; };
  pkgs = import (nixpkgs) { inherit system; };


  mkTest = nodes: testScript:
    testTools.simpleTest {
      inherit testScript;
      nodes = lib.mapAttrs (n: v: lib.recursiveUpdate v { config.networking.hostName = lib.mkForce n; }) nodes;
    };
in {
  simple = mkTest
    {
      node1 = {};
    }
    ({ nodes }: ''
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

      with subtest("nix flake runs"):
          node1.succeed("nix flake --help")
    '');

  kexec = mkTest
    {
      node1 = {};
      node2 = {
        # TODO we need to use the same priority as in base.nix here, because we just want to *add*,
        # not override our overriden systemPackages. Removing individual systemPackages in base.nix
        # instead of overriding the default set completely would be preferred, and should be possible
        # with extendModules, but I haven't got that to work with nixosTest yet.
        config.environment.systemPackages = lib.mkOverride 60 [ pkgs.hello ];
      };
    }
    ({ nodes }: ''
      start_all()
      with subtest("kexec works"):
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
    '');
}
