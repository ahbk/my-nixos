## _module\.args

Additional arguments passed to each module in addition to ones
like ` lib `, ` config `,
and ` pkgs `, ` modulesPath `\.

This option is also available to all submodules\. Submodules do not
inherit args from their parent module, nor do they provide args to
their parent module or sibling submodules\. The sole exception to
this is the argument ` name ` which is provided by
parent modules to a submodule and contains the attribute name
the submodule is bound to, or a unique generated name if it is
not bound to an attribute\.

Some arguments are already passed by default, of which the
following *cannot* be changed with this option:

 - ` lib `: The nixpkgs library\.

 - ` config `: The results of all options after merging the values from all modules together\.

 - ` options `: The options declared in all modules\.

 - ` specialArgs `: The ` specialArgs ` argument passed to ` evalModules `\.

 - All attributes of ` specialArgs `
   
   Whereas option values can generally depend on other option values
   thanks to laziness, this does not apply to ` imports `, which
   must be computed statically before anything else\.
   
   For this reason, callers of the module system can provide ` specialArgs `
   which are available during import resolution\.
   
   For NixOS, ` specialArgs ` includes
   ` modulesPath `, which allows you to import
   extra modules from the nixpkgs package tree without having to
   somehow make the module aware of the location of the
   ` nixpkgs ` or NixOS directories\.
   
   ```
   { modulesPath, ... }: {
     imports = [
       (modulesPath + "/profiles/minimal.nix")
     ];
   }
   ```

For NixOS, the default value for this option includes at least this argument:

 - ` pkgs `: The nixpkgs package set according to
   the ` nixpkgs.pkgs ` option\.



*Type:*
lazy attribute set of raw value

*Declared by:*
 - [lib/modules\.nix](https://github.com/ahbk/my-nixos/blob/master/lib/modules.nix)



## ahbk\.backup



Specification of one or more backup targets



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## ahbk\.backup\.\<name>\.enable



Whether to enable backup target\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## ahbk\.backup\.\<name>\.exclude



List of paths to not backup



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## ahbk\.backup\.\<name>\.paths



List of paths to backup



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## ahbk\.backup\.\<name>\.repository



Target repository



*Type:*
string

*Declared by:*
 - [modules/backup\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/backup.nix)



## ahbk\.de



Definition of per-user desktop environment



*Type:*
attribute set of (submodule)



*Default:*
` { } `

*Declared by:*
 - [modules/de\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/de.nix)



## ahbk\.de\.\<name>\.enable



Whether to enable Configure Desktop Environment for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [modules/de\.nix](https://github.com/ahbk/my-nixos/blob/master/modules/de.nix)



## ahbk-hm\.de\.enable



Whether to enable Configure Desktop Environment for this user\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [hm-modules/de\.nix](https://github.com/ahbk/my-nixos/blob/master/hm-modules/de.nix)


