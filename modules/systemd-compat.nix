{ lib, ... }:

with lib;

{
  options = {
    systemd.services = mkOption {
    };
    systemd.user = mkOption {
    };
  };
  config = {
  };
}
