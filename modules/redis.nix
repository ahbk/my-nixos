{
  config,
  lib,
  pkgs,
  ids,
  ...
}:
let
  cfg = config.my-nixos.redis;

  mkValueString =
    value:
    if value == true then
      "yes"
    else if value == false then
      "no"
    else
      lib.generators.mkValueStringDefault { } value;

  redisConfig =
    settings:
    pkgs.writeText "redis.conf" (
      lib.generators.toKeyValue {
        listsAsDuplicateKeys = true;
        mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } " ";
      } settings
    );

  redisName = name: "${name}-redis";
  enabledServers = lib.filterAttrs (name: conf: conf.enable) config.my-nixos.redis.servers;

in
{
  disabledModules = [ "services/databases/redis.nix" ];

  ###### interface

  options = rec {

    services.redis = my-nixos.redis;
    my-nixos.redis = {
      package = lib.mkPackageOption pkgs "redis" { };

      vmOverCommit =
        lib.mkEnableOption ''
          set `vm.overcommit_memory` sysctl to 1
          (Suggested for Background Saving: <https://redis.io/docs/get-started/faq/>)
        ''
        // {
          default = true;
        };

      servers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { config, name, ... }:
            {
              options = {
                enable = lib.mkEnableOption "Redis server";

                user = lib.mkOption {
                  type = lib.types.str;
                  default = redisName name;
                };

                group = lib.mkOption {
                  type = lib.types.str;
                  default = config.user;
                };

                port = lib.mkOption {
                  type = lib.types.port;
                  default = ids.${redisName name}.port;
                  description = ''
                    The TCP port to accept connections.
                    If port 0 is specified Redis will not listen on a TCP socket.
                  '';
                };

                openFirewall = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Whether to open ports in the firewall for the server.
                  '';
                };

                extraParams = lib.mkOption {
                  type = with lib.types; listOf str;
                  default = [ ];
                  description = "Extra parameters to append to redis-server invocation";
                  example = [ "--sentinel" ];
                };

                bind = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1";
                  description = ''
                    The IP interface to bind to.
                    `null` means "all interfaces".
                  '';
                  example = "192.0.2.1";
                };

                unixSocket = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = "/run/${redisName name}/redis.sock";
                  defaultText = lib.literalExpression ''
                    "/run/redis-''${name}/redis.sock"
                  '';
                  description = "The path to the socket to bind to.";
                };

                unixSocketPerm = lib.mkOption {
                  type = lib.types.int;
                  default = 660;
                  description = "Change permissions for the socket";
                  example = 600;
                };

                logLevel = lib.mkOption {
                  type = lib.types.str;
                  default = "notice";
                  example = "debug";
                  description = ''
                    Specify the server verbosity level, options:
                    debug, verbose, notice, warning.
                  '';
                };

                logfile = lib.mkOption {
                  type = lib.types.str;
                  default = "/dev/null";
                  description = ''
                    Specify the log file name. Also 'stdout' can be used to force
                    Redis to log on the standard output.
                  '';
                  example = "/var/log/redis.log";
                };

                syslog = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Enable logging to the system logger.";
                };

                databases = lib.mkOption {
                  type = lib.types.int;
                  default = 16;
                  description = "Set the number of databases.";
                };

                maxclients = lib.mkOption {
                  type = lib.types.int;
                  default = 10000;
                  description = "Set the max number of connected clients at the same time.";
                };

                save = lib.mkOption {
                  type = with lib.types; listOf (listOf int);
                  default = [
                    [
                      900
                      1
                    ]
                    [
                      300
                      10
                    ]
                    [
                      60
                      10000
                    ]
                  ];
                  description = ''
                    The schedule in which data is persisted to disk, represented
                    as a list of lists where the first element represent the
                    amount of seconds and the second the number of changes.

                    If set to the empty list (`[]`) then RDB persistence will be
                    disabled (useful if you are using AOF or don't want any
                    persistence).
                  '';
                };

                slaveOf = lib.mkOption {
                  type =
                    with lib.types;
                    nullOr (
                      submodule (
                        { ... }:
                        {
                          options = {
                            ip = lib.mkOption {
                              type = str;
                              description = "IP of the Redis master";
                            };

                            port = lib.mkOption {
                              type = port;
                              description = "port of the Redis master";
                            };
                          };
                        }
                      )
                    );

                  default = null;
                  description = "IP and port to which this redis instance acts as a slave.";
                  example = {
                    ip = "192.168.1.100";
                    port = 6379;
                  };
                };

                masterAuth = lib.mkOption {
                  type = with lib.types; nullOr str;
                  default = null;
                  description = ''
                    If the master is password protected (using the requirePass
                    configuration) it is possible to tell the slave to authenticate
                    before starting the replication synchronization process,
                    otherwise the master will refuse the slave request.
                    (STORED PLAIN TEXT, WORLD-READABLE IN NIX STORE)'';
                };

                requirePass = lib.mkOption {
                  type = with lib.types; nullOr str;
                  default = null;
                };

                requirePassFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "File with password for the database.";
                };

                appendOnly = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    By default data is only periodically persisted to disk, enable
                    this option to use an append-only file for improved
                    persistence.
                  '';
                };

                appendFsync = lib.mkOption {
                  type = lib.types.str;
                  default = "everysec"; # no, always, everysec
                  description = ''
                    How often to fsync the append-only log, options: no, always, everysec.
                  '';
                };

                slowLogLogSlowerThan = lib.mkOption {
                  type = lib.types.int;
                  default = 10000;
                  description = "Log queries whose execution take longer than X in milliseconds.";
                  example = 1000;
                };

                slowLogMaxLen = lib.mkOption {
                  type = lib.types.int;
                  default = 128;
                  description = "Maximum number of items to keep in slow log.";
                };

                settings = lib.mkOption {
                  type =
                    with lib.types;
                    attrsOf (oneOf [
                      bool
                      int
                      str
                      (listOf str)
                    ]);
                  default = { };
                  description = ''
                    Redis configuration. Refer to
                    <https://redis.io/topics/config>
                    for details on supported values.
                  '';
                  example = lib.literalExpression ''
                    {
                      loadmodule = [ "/path/to/my_module.so" "/path/to/other_module.so" ];
                    }
                  '';
                };
              };
              config.settings = lib.mkMerge [
                {
                  inherit (config)
                    port
                    logfile
                    databases
                    maxclients
                    appendOnly
                    ;
                  daemonize = false;
                  supervised = "systemd";
                  loglevel = config.logLevel;
                  syslog-enabled = config.syslog;
                  save =
                    if config.save == [ ] then
                      ''""'' # Disable saving with `save = ""`
                    else
                      map (d: "${toString (builtins.elemAt d 0)} ${toString (builtins.elemAt d 1)}") config.save;
                  dbfilename = "dump.rdb";
                  dir = "/var/lib/${redisName name}";
                  appendfsync = config.appendFsync;
                  slowlog-log-slower-than = config.slowLogLogSlowerThan;
                  slowlog-max-len = config.slowLogMaxLen;
                }
                (lib.mkIf (config.bind != null) { inherit (config) bind; })
                (lib.mkIf (config.unixSocket != null) {
                  unixsocket = config.unixSocket;
                  unixsocketperm = toString config.unixSocketPerm;
                })
                (lib.mkIf (config.slaveOf != null) {
                  slaveof = "${config.slaveOf.ip} ${toString config.slaveOf.port}";
                })
                (lib.mkIf (config.masterAuth != null) { masterauth = config.masterAuth; })
              ];
            }
          )
        );
        description = "Configuration of multiple `redis-server` instances.";
        default = { };
      };
    };

  };

  ###### implementation

  config = lib.mkIf (enabledServers != { }) {

    boot.kernel.sysctl = lib.mkIf cfg.vmOverCommit {
      "vm.overcommit_memory" = "1";
    };

    networking.firewall.allowedTCPPorts = lib.concatMap (
      conf: lib.optional conf.openFirewall conf.port
    ) (lib.attrValues enabledServers);

    environment.systemPackages = [ cfg.package ];

    users.users = lib.mapAttrs' (
      name: conf:
      lib.nameValuePair (redisName name) {
        description = "System user for the redis-server instance ${name}";
        inherit (ids.${redisName name}) uid;
        isSystemUser = true;
        group = redisName name;
      }
    ) enabledServers;
    users.groups = lib.mapAttrs' (
      name: conf:
      lib.nameValuePair (redisName name) {
        gid = ids.${redisName name}.uid;
      }
    ) enabledServers;

    preservation.preserveAt."/srv/database" = {
      directories = lib.mapAttrsToList (name: _: {
        directory = "/var/lib/${redisName name}";
        user = redisName name;
        group = redisName name;
      }) enabledServers;
    };

    systemd.services = lib.mapAttrs' (
      name: conf:
      lib.nameValuePair (redisName name) {
        description = "Redis Server - ${redisName name}";

        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStart = "${cfg.package}/bin/${
            cfg.package.serverBin or "redis-server"
          } /var/lib/${redisName name}/redis.conf ${lib.escapeShellArgs conf.extraParams}";
          ExecStartPre =
            "+"
            + pkgs.writeShellScript "${redisName name}-prep-conf" (
              let
                redisConfVar = "/var/lib/${redisName name}/redis.conf";
                redisConfRun = "/run/${redisName name}/nixos.conf";
                redisConfStore = redisConfig conf.settings;
              in
              ''
                touch "${redisConfVar}" "${redisConfRun}"
                chown '${redisName name}':'${redisName name}' "${redisConfVar}" "${redisConfRun}"
                chmod 0600 "${redisConfVar}" "${redisConfRun}"
                if [ ! -s ${redisConfVar} ]; then
                  echo 'include "${redisConfRun}"' > "${redisConfVar}"
                fi
                echo 'include "${redisConfStore}"' > "${redisConfRun}"
                ${lib.optionalString (conf.requirePassFile != null) ''
                  {
                    echo -n "requirepass "
                    cat ${lib.escapeShellArg conf.requirePassFile}
                  } >> "${redisConfRun}"
                ''}
              ''
            );
          Type = "notify";
          User = redisName name;
          Group = redisName name;
          RuntimeDirectory = redisName name;
          RuntimeDirectoryMode = "0750";
          StateDirectory = redisName name;
          StateDirectoryMode = "0700";
          UMask = "0077";
          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          LimitNOFILE = lib.mkDefault "${toString (conf.maxclients + 32)}";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          PrivateUsers = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = cfg.package.pname != "keydb";
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          PrivateMounts = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = "~@cpu-emulation @debug @keyring @memlock @mount @obsolete @privileged @resources @setuid";
        };
      }
    ) enabledServers;

  };
}
