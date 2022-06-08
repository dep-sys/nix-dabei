# nix-dabei

An **experimental** operating system generator heavily based on [not-os][], which in turn is based on [NixOS][nixos].

It generates a relatively small linux kernel, init ramdisk and squashfs image. Those can be booted from memory, without touching local disks.
This is useful for various setup and recovery tasks, such as installing NixOS on a remote machine.

# Motivation / Why?

I was looking for a generic way to install NixOS systems from [flakes][] on (possibly) remote systems, while still being able to use alternative file systems like [zfs][]. Installing NixOS from i.e. Hetzners rescue system works, but means that one is limited to features supported by Hetzners rescue kernel. While they do support zfs specifically, the installer compiles the module from source in the rescue system. This takes a lot of time and becomes annoying quickly if one tries to deploy multiple machines. Additionally, a mismatch between zfs versions and features between Hetzners kernel and NixOS is likely.

Luckily, `kexec`uting a NixOS kernel and init ramdisk from a rescue system works fine. So we can use easily customizable kernels and userland tools, including modern nix with flakes enabled, to install NixOS.

The resulting environment should be easy to customize and I will do my best to on-board new users and developers.
Contributions welcome! :tada:

# Todos & Ideas

* TODO: those should be migrated into github issues, whenever discussion is needed * implement & document kexec * check why perl seems to be incldued in toplevel? 
* add vm options submodule (and more ram)
* setup cache (b2?)
* setup github ci
* setup linter and fmter
* include zfs kernel and runtime
* write {read,write}-info.sh for hetzner

# Usage Tips 

(Most) available options are documented in [options documentation](./options.md) 

## Run virtual machine

```sh
nix build -L .#runvm && ./result
```

(You can kill it by entering `Ctrl-a x`)

## Check toplevel packages 

``` sh
nix build -L .#toplevel && du -h $(nix-store -qR result) --max=0 -BM|sort -n
```

## Check dist sizes

``` sh
nix build -L .#dist && du -h result/* 
```

# Differences and Similarities

## Compared to `system.build.netbootRamdisk`

My [first experiment][nixos-zfs-installer] used `system.build.netbootRamdisk` from nixpkgs. This worked well enough and I learned *a lot* about nix, but the resulting images ended up really large which made uploads to new systems tedious. As they are loaded into memory, bigger images also makes it impossible to run them on systems with little memory. One could surely further reduce the size of that experiment, but `not-os` allowed tme to iterate much quicker. 

## Compared to [not-os][]

`not-os` is a fantastic project which did the hard work of extracting a minimal set of nixos modules and further reducing its size by replacing systemd with runit,
`nix-dabei` wouldn't be here without it. 

* still uses runit instead of systemd to reduze size.
* is based on `nixos-22.05`, not `nixos-unstable`.
* uses a flake to allow easier re-use.
* includes flake-enabled nix by default.
* added a few more package overrides to reduze size, see `overlays.default`.
* dropped rasperry pi support #help-wanted
* dropped netroot support #help-wanted

## Compared to [nix-infect][]

`nix-infect` is another great project which allows users to install NixOS on remote systems. It's implemented as a shell script which bootstraps nix and installs nixos on an ext4 file system.
While this works well for a lot of use-cases, `kexec`uting, like `nix-dabei` does, allows us to partition filesystems with the same kernel and tools as in the new NixOS system to be installed. 

* allows access to custom file system setups and other kernel features during installation.
* supports far less cloud providers than `nix-infect`.



[flakes]: https://nixos.wiki/wiki/Flakes
[zfs]: http://openzfs.org/
[not-os]: https://github.com/cleverca22/not-os
[nixos]: https://nixos.org
[nix-infect]: https://github.com/elitak/nixos-infect
[nixpkgs]: https://github.com/nixos/nixpkgs/
[nixos-zfs-installer]: https://github.com/dep-sys/nixos-zfs-installer/
