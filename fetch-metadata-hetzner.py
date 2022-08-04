#!/usr/bin/env nix-shell
#!nix-shell -p python3 -p python3Packages.pyyaml -p python3Packages.requests -p python3Packages.ptpython -i python3
import requests
import yaml
from pathlib import Path


HETZNER_METADATA_URL = 'http://169.254.169.254/hetzner/v1/metadata/'


def fetch_metadata():
    response = requests.get(HETZNER_METADATA_URL)
    response.raise_for_status()
    return yaml.safe_load(response.text)


if __name__ == '__main__':
    metadata = fetch_metadata()

    hostname = metadata.get('hostname')
    ssh_keys = metadata.get('public-keys')

    assert metadata.get('network-config', {}).get('version') == 1
    _network_config = metadata.get('network-config', {}).get('config')


    from ptpython.repl import embed
    embed(globals(), locals())
