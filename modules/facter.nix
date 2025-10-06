{
  config,
  host,
  inputs,
  lib,
  ...
}:
let
  cfg = config.my-nixos.facter;
in
{
  imports = [
    inputs.nixos-facter-modules.nixosModules.facter
  ];
  options.my-nixos.facter = {
    enable = lib.mkEnableOption "facter hardware configuration";
  };
  config = lib.mkIf (cfg.enable) {
    facter.reportPath = ../hosts/${host.name}/facter.json;
  };
}
