# nix-dabei

An **experimental** operating system generator based on [NixOS][nixos].

It generates a relatively small linux kernel and an initial ramdisk - all together ~40MB zstd-compressed at time of writing - that can either be booted conventionally or kexec'ed into from a running system. This can be useful for a variety of tasks, especially rescue systems and installers.

The current implementation focuses on the latter, and allows users to bootstrap NixOS on a remote machine via SSH only while still being able to use a nixos kernel, all its filesystem support and userland features during installation.

It's in development but already somewhat useable to deploy NixOS remotely with ZFS via kexec. Documentation is still lacking though as tradition demands.

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
nix run -L .#installerVM
```
(You can kill it by entering `Ctrl-a x`)

The VM can be accessed via SSH:

```sh
# Required once; git doesn'tt track file permissions but `ssh` enforces secure key file permissions.
chmod go-rwx fixtures/id_*

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -p 2222 -i fixtures/id_ed25519 root@localhost
```

## Run it on a real host

``` sh
# build a kexec bundle
kexec="$(nix build .#kexec --no-link --print-out-paths)"

# copy it to your $TARGET_SERVER
rsync \
    -Lavz \
    --info=progress2 \
    "${kexec}/" \
    root@$TARGET_SERVER:
# use the bundled script to switch into the initrd 
ssh root@$TARGET_SERVER "./kexec-boot flake_url=github:phaer/test-flake#nixosConfigurations.web-01"
```


# Differences and Similarities

## Compared to `system.build.netbootRamdisk`

My [first experiment][nixos-zfs-installer] used `system.build.netbootRamdisk` from nixpkgs. This worked well enough and I learned *a lot* about nix, but the resulting images ended up really large which made uploads to new systems tedious. As they are loaded into memory, bigger images also makes it impossible to run them on systems with little memory. 

## Compared to [not-os][]

My [second iteration][nix-dabei-not-os] was build upon `not-os`, which is a fantastic project that did the hard work of extracting a minimal set of nixos modules and further reducing its size by replacing systemd with runit.

This worked well enough, but then [systemd-in-stage1][] landed in nixos, simplifying the boot process and tempting me to see whether I could build something similar as `not-os` while staying closer to upstream NixOS.

## Compared to [nix-infect][]

`nix-infect` is another great project which allows users to install NixOS on remote systems. It's implemented as a shell script which bootstraps nix and installs nixos on an ext4 file system.
While this works as long as you are happy with ext4, `kexec`uting, like `nix-dabei` does, allows us to partition filesystems with the same kernel and tools as in the new NixOS system to be installed. 

## Compared to (official) ISO images

Official ISO images are great for interactive installations, but don't enable SSH access by default. You can build custom ones for your setup but depending on your provider getting those to boot can be somewhat more involved than `kexec`.


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

