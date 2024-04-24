{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption types mkIf mdDoc;
  cfg = config.ahbk.inadyn;
in {
  options = {

    ahbk.inadyn = with types; {

      enable = lib.mkEnableOption (mdDoc ''
        Synchronize your machine's IP address with a dynamic DNS provider using inadyn
      '');

      configFile = mkOption {
        type = nullOr path;
        default = null;
        example = ./inadyn/extraConfig.conf;
        description = mdDoc ''
          Include this file in `inadyn.conf`.
        '';
      };

      providers = mkOption {
        default = {};
        type = attrsOf (submodule (
          { name, config, options, ... }:
          { 
            options = {

              username = mkOption {
                type = str;
                example = "alice@mail.com";
                description = mdDoc ''
                  Username for the provider.
                '';
              };

              passwordFile = mkOption {
                type = path;
                example = "/run/freedns.pw";
                description = mdDoc ''
                  A file containing the password declaration.

                  Note that the full password declaration is needed:
                  ```
                  password=your-secret-password
                  ```
                '';
              };

              provider = mkOption {
                type = str;
                default = name;
                defaultText = "<name>";
                description = mdDoc ''
                  Specify one of the predefined providers, <name> by default.
                  '';
              };

              hostname = mkOption {
                type = str;
                description = mdDoc ''
                  Domain(s) that should point to your IP.
                  '';
                example = "{ myhost.ddns.net, \"*.otherhost.ddns.net\" }";
              };

            };
          }
        ));
      };

    };
  };

  config = with builtins; let

    providersConf = lib.concatStrings (map (p: ''
      provider ${p.provider} {
          include("${p.passwordFile}")
          username = ${p.username}
          hostname = ${p.hostname}
      }
    '') (attrValues cfg.providers));

    configFile = providersConf + (let
      f = cfg.configFile;
    in lib.optionalString (f != null) "include(\"${f}\")\n");

  in mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.inadyn ];
      etc."inadyn.conf".text = configFile;
    };

    systemd.services.inadyn = {
      documentation = [
        "man:inadyn"
        "man:inadyn.conf"
        "file:${pkgs.inadyn}/share/doc/inadyn/README.md"
      ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = pkgs.inadyn + "/bin/inadyn --foreground";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
