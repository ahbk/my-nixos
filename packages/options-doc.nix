{
  lib,
  runCommand,
  nixosOptionsDoc,
  pkgs,
  ...
}:

let
  inherit (pkgs.lib) removePrefix;

  eval = lib.evalModules {
    modules = [
      { _module.check = false; }
      ../modules/backup.nix
      ../modules/desktop-env.nix
      ../modules/django-react.nix
      ../modules/django-svelte.nix
      ../modules/django.nix
      ../modules/fail2ban.nix
      ../modules/fastapi-svelte.nix
      ../modules/fastapi.nix
      ../modules/glesys-updaterecord.nix
      ../modules/hm.nix
      ../modules/ide.nix
      ../modules/mailserver.nix
      ../modules/mysql.nix
      ../modules/nix.nix
      ../modules/postgresql.nix
      ../modules/react.nix
      ../modules/sendmail.nix
      ../modules/shell.nix
      ../modules/svelte.nix
      ../modules/system.nix
      ../modules/users.nix
      ../modules/vd.nix
      ../modules/wireguard.nix
      ../modules/wordpress.nix
      ../hm-modules/desktop-env.nix
      ../hm-modules/ide.nix
      ../hm-modules/shell.nix
      ../hm-modules/user.nix
      ../hm-modules/vd.nix
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
