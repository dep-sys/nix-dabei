{
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    ...
  }: {
    formatter = pkgs.alejandra;
  };
}
