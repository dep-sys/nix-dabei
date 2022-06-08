## environment.extraOutputsToInstall
List of additional package outputs to be symlinked into <filename>/run/current-system/sw</filename>.

*_Type_*:
list of string


*_Default_*
```
[]
```


*_Example_*
```
["doc","info","docdev"]
```


## environment.pathsToLink
List of directories to be symlinked in <filename>/run/current-system/sw</filename>.

*_Type_*:
list of string


*_Default_*
```
[]
```


*_Example_*
```
["/"]
```


## environment.systemPackages
The set of packages that appear in
/run/current-system/sw.  These packages are
automatically available to all users, and are
automatically updated every time you rebuild the system
configuration.  (The latter is the main difference with
installing them in the default profile,
<filename>/nix/var/nix/profiles/default</filename>.


*_Type_*:
list of package


*_Default_*
```
[]
```


*_Example_*
```
{"_type":"literalExpression","text":"[ pkgs.firefox pkgs.thunderbird ]"}
```


## hardware.firmware
List of packages containing firmware files.  Such files
will be loaded automatically if the kernel asks for them
(i.e., when it has detected specific hardware that requires
firmware to function).  If multiple packages contain firmware
files with the same name, the first package in the list takes
precedence.  Note that you must rebuild your system if you add
files to any of these directories.


*_Type_*:
list of package


*_Default_*
```
[]
```




## networking.nameservers
The list of nameservers.  It can be left empty if it is auto-detected through DHCP.


*_Type_*:
list of string


*_Default_*
```
[]
```


*_Example_*
```
["130.161.158.4","130.161.33.17"]
```


## networking.timeServers
The set of NTP servers from which to synchronise.


*_Type_*:
list of string


*_Default_*
```
["0.nixos.pool.ntp.org","1.nixos.pool.ntp.org","2.nixos.pool.ntp.org","3.nixos.pool.ntp.org"]
```




## nix-dabei.nix
Enable nix-daemon and a writeable store.

*_Type_*:
boolean






## nix-dabei.preMount
Shell commands to execute in stage-1, before root file system is mounted.
Useful for debugging.

*_Type_*:
strings concatenated with "\n"


*_Default_*
```
""
```




## nix-dabei.simpleStaticIp
set a static ip of 10.0.2.15

*_Type_*:
boolean


*_Default_*
```
false
```




