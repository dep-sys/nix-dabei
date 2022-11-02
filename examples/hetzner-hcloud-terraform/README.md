# Hetzner + TerraForm example

The code contained in this folder ties together
- `nix-dabei` release `v0.1` (deprecated as of 2022-10-02)
- [`terranix`](https://terranix.org/) and TerraForm to automatically create cloud resources (see `infra.nix`)
- [`colmena`](https://github.com/zhaofengli/colmena) for ongoing management of deployed resources

## Getting started

To get started you need to pre-configure TerraForm with:

### Credentials

If no credentials are provided TerraForm will ask for them at the start of
every execution. The easiest (not the most secure) way to provide credentials
is through the use of shell environment variables. The following variables are
required: 

- `TF_VAR_cloudflare_token` - A valid API token created through the Cloudflare dashboard,
  with 'Edit zone DNS' permission & scoped to the domain to be used.
  Configuration options for API tokens can be found in the profile section of an user account.
- `TF_VAR_cloudflare_zone_id` - The Cloudflare identifier for the DNS zone. Can be found in
  the Dashboard after selecting a domain.
- `TF_VAR_hcloud_token` - A valid API token for a project in the Hetzner Cloud. Any servers
  of the TerraForm resource type `hcloud_server` will be created within this project.
  Configuration options for API tokens can be found in the 'Security' section of a cloud project.


### Initialize TerraForm

TerraForm must first be initialized via the command
```shell
terraform init
```

## Changing cloud resources

The cloud resources are described in the `infra.nix`. `terranix` is used to convert nix expressions
into TerraForms JSON format. See https://terranix.org/documentation/


## Deploying resources

Resources can be deployed/ created via the command
```shell
nix build .#
result/bin/terraform apply
```


## Destroying resources
Resources can be deployed/ created via the command
```shell
nix build .#
result/bin/terraform destroy
```

WARNING: After confirmation this command deletes __EVERY__ resource defined in your
`infra.nix` file. If this is not what you intend to do, read the TerraForm documentation at
https://developer.hashicorp.com/terraform.

  
