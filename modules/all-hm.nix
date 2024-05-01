ahbk: user:
{ inputs
, lib
, ...
}:
let
  modules = [
    "user"
    "shell"
    "ide"
    "vd"
    "de"
  ];
  # HM-modules can't read NixOS options so they need to be passed to them from the caller.
  # So the *-hm.nix aren't really modules but functions that return modules.
  # `load-hm` passes the ahbk configuration and imports the result, like NixOS modules do.
  # It's not pretty, but the actual problem is probably that home-manager should have their own options.
  load-hm = m: (
    if lib.attrsets.attrByPath [ m user "enable" ] false ahbk
    then import ./${m}-hm.nix ahbk user ahbk.${m}.${user}
    else null
    ); 
in {
  imports = builtins.filter (m: m != null) (map load-hm modules);
}
