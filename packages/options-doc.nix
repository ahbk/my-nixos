{
  lib,
  runCommand,
  nixosOptionsDoc,
  pkgs,
  ...
}:

let
  inherit (pkgs.lib) hasPrefix removePrefix;

  eval = lib.evalModules {
    check = false;
    modules = [
      ../modules/backup.nix
      ../modules/desktop-env.nix
      ../modules/django.nix
      ../modules/django-svelte.nix
      ../modules/fastapi.nix
      ../modules/fastapi-svelte.nix
      ../modules/glesys-updaterecord.nix
      ../modules/hm.nix
      ../modules/ide.nix
      ../modules/mail-client.nix
      ../modules/mailserver.nix
      ../modules/mysql.nix
      ../modules/nginx.nix
      ../modules/postgresql.nix
      ../modules/shell.nix
      ../modules/svelte.nix
      ../modules/user.nix
      ../modules/vd.nix
      ../modules/wireguard.nix
      ../modules/wordpress.nix
      ../hm-modules/desktop-env.nix
      ../hm-modules/ide.nix
    ];
  };
  optionsDoc = nixosOptionsDoc {
    inherit (eval) options;
    transformOptions =
      opt:
      opt
      // {
        declarations = map (
          decl:
          let
            subpath = removePrefix "/" (removePrefix (toString ./..) (toString decl));
          in
          {
            url = "https://github.com/ahbk/my-nixos/blob/master/${subpath}";
            name = subpath;
          }
        ) opt.declarations;
      };
  };
in
runCommand "options-doc.md" { } ''
  cat ${optionsDoc.optionsCommonMark} >> $out
''
