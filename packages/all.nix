{ pkgs
}:

{
  odoo = pkgs.callPackage ./odoo.nix {};
  options-doc = pkgs.callPackage ./options-doc.nix {};
}
