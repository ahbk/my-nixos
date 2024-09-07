{ lib, pkgs, ... }:
let
  inherit (lib)
    concatStringsSep
    elem
    filterAttrs
    foldlAttrs
    mapAttrsToList
    recursiveUpdate
    ;
  inherit (pkgs) writeText;
in
{
  # pick a list of attributes from an attrSet
  pick = attrNames: attrSet: filterAttrs (name: value: elem name attrNames) attrSet;

  # create an env-file (package) that can be sourced to set environment variables
  mkEnv =
    name: value:
    writeText "${name}-env" (concatStringsSep "\n" (mapAttrsToList (n: v: "${n}=${v}") value));

  # loop over an attrSet and merge the attrSets returned from f into one (latter override the former in case of conflict)
  mergeAttrs =
    f: attrs:
    foldlAttrs (
      acc: name: value:
      (recursiveUpdate acc (f name value))
    ) { } attrs;
}
