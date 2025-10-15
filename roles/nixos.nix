{
  host,
  ...
}:
{
  imports = [
    ../hosts/${host.name}/configuration.nix
    ../modules/system.nix
  ];
}
