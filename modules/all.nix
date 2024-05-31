{ inputs
, ...
}:
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-mailserver.nixosModules.default
    ./backup.nix
    ./chatddx.nix
    ./django.nix
    ./de.nix
    ./fastapi.nix
    ./glesys-updaterecord.nix
    ./hm.nix
    ./ide.nix
    ./laptop.nix
    ./mail-client.nix
    ./mail-server.nix
    ./mysql.nix
    ./nginx.nix
    ./nix.nix
    ./odoo.nix
    ./postgresql.nix
    ./shell.nix
    ./svelte.nix
    ./sverigesval.nix
    ./system.nix
    ./user.nix
    ./vd.nix
    ./wg-client.nix
    ./wg-server.nix
    ./wordpress.nix
  ];

}
