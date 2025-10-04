{
  config,
  lib,
  ids,
  ...
}:
let
  inherit (lib)
    mkOption
    mkMerge
    types
    ;
in
{
  options.my-nixos.redis-servers = mkOption {
    type = types.listOf types.str;
    default = [ ];
    description = "List of redis servers to start";
  };

  config = {
    users.users = builtins.listToAttrs (
      map (name: {
        name = "redis-${name}";
        value.uid = ids."redis-${name}".uid;
      }) config.my-nixos.redis-servers
    );
    services.redis.servers = builtins.listToAttrs (
      map (name: {
        name = name;
        value = {
          inherit (ids."redis-${name}") port;
          enable = true;
          settings.syslog-ident = "redis-${name}";
        };
      }) config.my-nixos.redis-servers
    );
  };
}
