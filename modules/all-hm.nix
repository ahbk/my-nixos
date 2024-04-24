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
  load-hm = m: (
    if lib.attrsets.attrByPath [ m user "enable" ] false ahbk
    then import ./${m}-hm.nix ahbk user ahbk.${m}.${user}
    else null
    ); 
in {
  imports = builtins.filter (m: m != null) (map load-hm modules);
}
