{ lib, ... }: {
  pick = attrNames: attrSet: lib.filterAttrs (name: value: lib.elem name attrNames) attrSet;
}
