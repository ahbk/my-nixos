{ lib
, runCommand
, nixosOptionsDoc
, pkgs
, ...
}:

let
  inherit (pkgs.lib)
    hasPrefix
    removePrefix
    ;

  eval = lib.evalModules {
    check = false;
    modules = [
      ../modules/backup.nix
      ../modules/de.nix
      ../hm-modules/de.nix
    ];
  };
  optionsDoc = nixosOptionsDoc {
    inherit (eval) options;
    transformOptions = opt: opt // {
      declarations =
        map (decl:
          let subpath = removePrefix "/" (removePrefix (toString ./..) (toString decl));
          in { url = "https://github.com/ahbk/my-nixos/blob/master/${subpath}"; name = subpath; }
          ) opt.declarations;
      };
    };
in
  runCommand "options-doc.md" {} ''
  cat ${optionsDoc.optionsCommonMark} >> $out
  ''
