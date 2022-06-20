# nix-dabei

An **experimental** operating system generator heavily based on [not-os][], which in turn is based on [NixOS][nixos].

It generates a relatively small linux kernel, init ramdisk and squashfs image. Those can then be booted into memory in various ways and without touching any
local disks.
This is useful for a variety of setup and recovery tasks. For example to bootstrap NixOS on a remote machine via SSH only while still being able to use
a nixos kernel, its filesystem support and userland features during installation.

While it's very early in development and major features such as zfs support are still missing, but it's at a stage where it might be interesting to NixOS developers.

There's a binary cache at [cachix: nix-dabei](https://app.cachix.org/cache/nix-dabei).

# Motivation / Why?

I was looking for a generic way to install NixOS systems from [flakes][flakes] on (possibly) remote systems, while still being able to use alternative file systems like [zfs][]. We could install NixOS from i.e. Hetzners rescue system, but that means we are limited to features supported by Hetzners rescue kernel. While they do support zfs specifically, the installer compiles the module from source in the rescue system. This takes a lot of time and becomes annoying quickly if one tries to deploy multiple machines. Additionally, a mismatch between zfs versions and features between Hetzners kernel and NixOS is likely.

Luckily, `kexec`uting a NixOS kernel and init ramdisk from a rescue system works fine. So we can use custom kernels and userland tools, including modern nix with flakes enabled, to install NixOS.

It ****should** work for other cloud providers and environments, such as rasperrrypi as well, but that's not really tested yet. Contributions welcome!
:tada:

# Tasks / What's left?

## Automated Tests

## 0-click provisioning (hetzner cloud)

* Write bootstraping/seeding scripts for hetzner

## ZFS support and PoC partitioner

* include zfs kernel and runtime
* implement partitioner (single disk)
* implement example with encrypted boot
* implement partitioner and test for mirrored layouts

## Reduce Closure Size

* check why perl seems to be included in toplevel? 
* explore using systemd-minimal now that systemd in stage-1 has landed.
* dive deeper into initrd generation:
  * can we do without squashfs? I think yes

## Documentation & Tooling

* add options submodule to customize vm runner
  (e.g. add more ram, disable networking, boot devices, etc)
* write new documentation tooling, look into what colmena and friends are doing

# Usage / What can I do with? 

## Run virtual machine

```sh
nix build -L .#runvm && ./result
```

(You can kill it by entering `Ctrl-a x`)

## Check toplevel packages 

List of contents, sorted by size

``` sh
nix build -L .#toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
```

Interactively browse contents

``` sh
nix run nixpkgs#nix-tree  .#toplevel
```


# Differences and Similarities

## Compared to `system.build.netbootRamdisk`

My [first experiment][nixos-zfs-installer] used `system.build.netbootRamdisk` from nixpkgs. This worked well enough and I learned *a lot* about nix, but the resulting images ended up really large which made uploads to new systems tedious. As they are loaded into memory, bigger images also makes it impossible to run them on systems with little memory. One could surely further reduce the size of that experiment, but `not-os` allowed tme to iterate much quicker. 

## Compared to [not-os][]

My [second iteration][nix-dabei-not-os] was build upon `not-os`, which is a fantastic project that did the hard work of extracting a minimal set of nixos modules and further reducing its size by replacing systemd with runit,

This worked well and the resulting images ended up to be smaller than current iterations of `nix-dabei`. But then [systemd-in-stage1][] landed in nixos, simplifying the boot process and tempting me to see whether I could build
something similar as `not-os` while staying closer to upstream NixOS.

In the end, `nix-dabei` does not support raspberrypi yet and produces bigger images, but uses systemd and a is packaged as a flake.

## Compared to [nix-infect][]

`nix-infect` is another great project which allows users to install NixOS on remote systems. It's implemented as a shell script which bootstraps nix and installs nixos on an ext4 file system.
While this works well for a lot of use-cases, `kexec`uting, like `nix-dabei` does, allows us to partition filesystems with the same kernel and tools as in the new NixOS system to be installed. 

* allows access to custom file system setups and other kernel features during installation.
* supports far less cloud providers than `nix-infect`.

## The official ISO images




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
