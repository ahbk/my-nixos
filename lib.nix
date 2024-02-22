{ lib, pkgs, ... }:
with lib;
{
  pick = attrNames: attrSet: lib.filterAttrs (name: value: lib.elem name attrNames) attrSet;
  mkEnv = name: value: pkgs.writeText "${name}-env" (concatStringsSep "\n" (mapAttrsToList (n: v: "${n}=${v}") value));
  mergeAttrs = f: attrs: foldlAttrs (acc: name: value: (recursiveUpdate acc (f name value))) {} attrs;
}
