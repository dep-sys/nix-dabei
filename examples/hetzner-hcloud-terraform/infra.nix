{ lib, ... }:
let
  hostRecords = makeDualStack makePrimaryRecord hosts;
  #subDomainRecords = makeDualStack makeHostRecord subdomains;
  dnsRecords = hostRecords; # // subDomainRecords;
  reverseRecords = makeDualStack makeHostReverseRecord hosts;
  hostDefaults = {
    domain = "fancy.systems";
  };
  hosts = {
    web-01 = hostDefaults // {};
#    web-02 = hostDefaults // {};
  };

  makeHost = name: data: {
    name = "${name}.${data.domain}";
    server_type = "cx11";
    image = "debian-10";
    rescue = "linux64";
    location = "nbg1";
    ssh_keys = [
      #"\${hcloud_ssh_key.yubikey.id}"
      "ssh key"
    ];

    provisioner.remote-exec = {
      inline = [
        "curl -L -o hcloud-do-install.sh https://github.com/dep-sys/nix-dabei/releases/latest/download/hcloud-do-install.sh"
        "bash hcloud-do-install.sh github:dep-sys/nix-dabei?ref=terraform&dir=examples/hetzner-hcloud-terraform#my-little-webserver"
      ];
      on_failure = "continue";
      connection = {
        type = "ssh";
        user = "root";
        host = "\${self.ipv4_address}";
      };
    };
  };

  nameValuePairToAttrset = nvp: { "${nvp.name}" = nvp.value; };
  toTerraformIdentifier = lib.replaceStrings ["." "*"] ["_" "wildcard"];
  hostDomainName = name: "${name}.hosts";
  getIPVersion = type: "ipv${ if type == "AAAA" then "6" else "4" }";

  makeRecord = { name, type, value}@args:
    lib.nameValuePair
      "${toTerraformIdentifier name}-${lib.toLower(type)}"
      (args // {
        zone_id = "\${var.cloudflare_zone_id}";
        ttl = "300";
        proxied = "false";
      });

  makeHostRecord = type: name: hostName: makeRecord {
    inherit name type;
    value = "\${hcloud_server.${hostName}.${getIPVersion type}_address}";
  };
  makePrimaryRecord = type: name: data: (makeHostRecord type "${name}.hosts" name);
  makeDualStack = f: args:
    (lib.mapAttrs' (f "A") args)
    // (lib.mapAttrs' (f "AAAA") args);

  makeHostReverseRecord = type: name: data:
    lib.nameValuePair
      "${toTerraformIdentifier name}-${type}"
      {
        server_id  = "\${hcloud_server.${name}.id}";
        ip_address = "\${hcloud_server.${name}.${getIPVersion type}_address}";
        dns_ptr    = "${name}.hosts.${data.domain}";
      };
in
{
  terraform.required_providers = {
    cloudflare = {
      source = "cloudflare/cloudflare";
    };
    hcloud = {
      source = "hetznercloud/hcloud";
    };
  };

  variable = {
    hcloud_token.sensitive = true;
    cloudflare_token.sensitive = true;
    cloudflare_zone_id.sensitive = true;
  };

  provider = {
    hcloud = {
      token = "\${var.hcloud_token}";
    };
    cloudflare = {
      api_token = "\${var.cloudflare_token}";
    };
  };

  resource.hcloud_server = lib.mapAttrs makeHost hosts;
    resource.hcloud_rdns = reverseRecords;
    resource.cloudflare_record = dnsRecords;

#  resource.hcloud_ssh_key.yubikey = {
#    name = "my ssh key";
#    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLopgIL2JS/XtosC8K+qQ1ZwkOe1gFi8w2i1cd13UehWwkxeguU6r26VpcGn8gfh6lVbxf22Z9T2Le8loYAhxANaPghvAOqYQH/PJPRztdimhkj2h7SNjP1/cuwlQYuxr/zEy43j0kK0flieKWirzQwH4kNXWrscHgerHOMVuQtTJ4Ryq4GIIxSg17VVTA89tcywGCL+3Nk4URe5x92fb8T2ZEk8T9p1eSUL+E72m7W7vjExpx1PLHgfSUYIkSGBr8bSWf3O1PW6EuOgwBGidOME4Y7xNgWxSB/vgyHx3/3q5ThH0b8Gb3qsWdN22ZILRAeui2VhtdUZeuf2JYYh8L";
#  };


  output.hosts.value = lib.mapAttrs (name: data: {
    domainName = "${name}.hosts.${data.domain}";
    interface = "eth0";
    ipv4 = {
      address = "\${hcloud_server.${name}.ipv4_address}";
      prefixLength = 32;
      gateway = "172.31.1.1";
    };
    ipv6 = {
      address = "\${hcloud_server.${name}.ipv6_address}";
      prefixLength = 64;
      gateway = "fe80::1";
    };
  }) hosts;

}
