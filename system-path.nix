# Copied from https://github.com/vikanezrimaya/nixos-super-minimal/blob/master/system-path.nix
#
## This module defines the packages that appear in
# /run/current-system/sw.

{ config, lib, pkgs, ... }:

with lib;

let

  requiredPackages = map (pkg: setPrio ((pkg.meta.priority or 5) + 3) pkg) [
      # Packages that are absolutely neccesary
      pkgs.bashInteractive # bash with ncurses support
      # Packages that are probably neccesary
      pkgs.su # Requires a SUID wrapper - should be installed in system path?
      pkgs.coreutils # I've seen environments that don't even need coreutils - they are pulled with Nix instead
      #pkgs.ncurses # Includes things such as `reset` - you should have it nearby
      pkgs.stdenv.cc.libc # I sure hope it's here for a reason
      # Packages that might not be so neccesary
      #pkgs.acl # I don't remember the last time I used one of these
      #pkgs.curl # Can be pulled in case network access is required
      #pkgs.attr # see pkgs.acl note
      #pkgs.bzip2
      #pkgs.cpio
      #pkgs.diffutils
      #pkgs.findutils
      #pkgs.gawk
      #pkgs.getent # Clearly this is a useless utility for me
      #pkgs.getconf # What is this?
      #pkgs.gnugrep
      #pkgs.gnupatch
      #pkgs.gnused
      #pkgs.gnutar
      #pkgs.gzip
      #pkgs.xz
      #pkgs.less
      #pkgs.libcap
      #pkgs.nano # Could be downloaded separately
      #pkgs.netcat # Totally unneccesary in a minimal system - NixOS is generous in even providing this in the default closure, some systems don't do that
      #config.programs.ssh.package # Don't install by default, but include in system closure since it can't be separated from the daemon
      #pkgs.mkpasswd # We manage users declaratively
      #pkgs.procps # It can be useful, but not strictly neccesary
      #pkgs.time # we can measure time using the shell builtin
      #pkgs.utillinux
      #pkgs.which
      #pkgs.zstd
    ];

    defaultPackages = map (pkg: setPrio ((pkg.meta.priority or 5) + 3) pkg)
      [ pkgs.perl
      ];

in

{
  config = {

    environment.systemPackages = requiredPackages ++ config.environment.defaultPackages;

    environment.pathsToLink =
      [ "/bin"
        "/lib" # FIXME: remove and update debug-info.nix
        "/sbin"
        "/share/systemd"
      ];

    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
      ignoreCollisions = true;
      # !!! Hacky, should modularise.
      # outputs TODO: note that the tools will often not be linked by default
      postBuild =
        ''
          # Remove wrapped binaries, they shouldn't be accessible via PATH.
          find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete

          if [ -x $out/bin/glib-compile-schemas -a -w $out/share/glib-2.0/schemas ]; then
              $out/bin/glib-compile-schemas $out/share/glib-2.0/schemas
          fi

          ${config.environment.extraSetup}
        '';
    };

  };
}
