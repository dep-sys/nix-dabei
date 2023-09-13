# archived

Needs to be updated & could need a clean-up as I started this project when I was still relatively new to the internals of NixOS.
I likely won't work on this any more as kexec images from https://github.com/nix-community/nixos-images/ got small enough for my own use-cases (machines with 2GB memory).
Could still be useful for even smaller machines, so feel free to ping me if you got a use-case and want to continue working on it and/or fund other people to do so.


# nix-dabei

An **experimental** operating system generator based on [NixOS][nixos].

It generates a relatively small linux kernel and an initial ramdisk - all together ~40MB zstd-compressed at time of writing - that can either be booted conventionally or kexec'ed into from a running system. This can be useful for a variety of tasks, especially rescue systems and installers.

The current implementation focuses on being an alternative kexec bundle for [nixos-remote](https://github.com/numtide/nixos-remote). You use the tar.gz from [the latest release](https://github.com/dep-sys/nix-dabei/release) with `nixos-remote --kexec $nix-dabei.tar.gz`. As it's less than 10% in size compared to the [default image](https://github.com/nix-community/nixos-images/tree/main/nix/kexec-installer), downloading it on the target host will be faster and kexec should work on hosts with less than 1GB of RAM. 

There's a binary cache at [cachix: nix-dabei](https://app.cachix.org/cache/nix-dabei).

# Motivation / Why?

I was looking for a generic way to install NixOS systems from [flakes][flakes] on (possibly) remote systems, while still being able to use alternative file systems like [zfs][]. We could install NixOS from i.e. Hetzners rescue system, but that means we are limited to features supported by Hetzners rescue kernel. While they do support zfs specifically, the installer compiles the module from source in the rescue system. This takes a lot of time and becomes annoying quickly if one tries to deploy multiple machines. Additionally, a mismatch between zfs versions and features between Hetzners kernel and NixOS is likely.

Luckily, `kexec`uting a NixOS kernel and init ramdisk from a debian image or rescue system works fine. So we can use custom kernels and userland tools, including modern nix with flakes enabled, to install NixOS.

It **should** work for other cloud providers and environments, such as rasperrrypi as well, but that's not really tested yet. Contributions welcome!
:tada:

# Usage / What can I do with? 

## Run the initrd in a virtual machine

...with a mounted empty disk, which is useful for testing and development:

```sh
nix run -L .#vm
```
(You can kill it by entering `Ctrl-a x`)

The VM can be accessed via SSH:

```sh
# Required once; git doesn'tt track file permissions but `ssh` enforces secure key file permissions.
chmod go-rwx fixtures/id_*

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -p 2222 -i fixtures/id_ed25519 root@localhost
```

[flakes]: https://nixos.wiki/wiki/Flakes
[zfs]: http://openzfs.org/
[not-os]: https://github.com/cleverca22/not-os
[nixos]: https://nixos.org
[nix-infect]: https://github.com/elitak/nixos-infect
[nixpkgs]: https://github.com/nixos/nixpkgs/
[nixos-zfs-installer]: https://github.com/dep-sys/nixos-zfs-installer/
[nix-dabei-notos]: https://github.com/dep-sys/nix-dabei/tree/not-os
[hetzner.cloud]: https://hetzner.cloud
[systemd-in-stage1]: https://github.com/NixOS/nixpkgs/projects/51

