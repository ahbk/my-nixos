{
  config,
  lib,
  options,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  debug = options.preservation.preserveAt.type.nestedTypes;
  cfg = config.my-nixos.debug;
in
{
  options.my-nixos.debug = {
    enable = mkOption {
      description = ''Enable this debugging module'';
      type = types.bool;
      default = false;
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = false;
        message = "Debug: subOptions has keys: ${builtins.concatStringsSep ", " (builtins.attrNames debug)}";
      }
    ];
  };

}
