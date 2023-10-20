{ config, pkgs, lib, ...}:
let
  inherit (lib) mkOption types mkIf mdDoc;
  cfg = config.services.networking.inadyn;
in {
  options = {

    services.networking.inadyn = with types; {

      enable = mkOption {
        type = bool;
        default = false;
        description = mdDoc "Install and run inadyn as a service";
        relatedPackages = [ "inadyn" ];
      };

      verify-address = mkOption {
        type = nullOr bool;
        default = null;
        description = mdDoc "IP address validation can be disabled by setting this option to `false`";
      };

      fake-address = mkOption {
        type = nullOr bool;
        default = null;
        description = mdDoc "Use fake address to keep account alive";
      };

      allow-ipv6 = mkOption {
        type = nullOr bool;
        default = null;
        description = mdDoc "Discard IPv6 addresses";
      };

      iface = mkOption {
        type = nullOr str;
        default = null;
        example = "enp3s0";
        description = mdDoc "Use network interface as source of IP address";
      };

      iterations = mkOption {
        type = nullOr int;
        default = null;
        example = 10;
        description = mdDoc "Number of DNS update (0=infinite)";
      };

      period = mkOption {
        type = nullOr int;
        default = null;
        example = 300;
        description = mdDoc "Interval between updates in seconds (default ~1 minute)";
      };

      forced-update = mkOption {
        type = nullOr int;
        default = null;
        example = 60000;
        description = mdDoc "Interval between updates even if IP is not changed (default 30 days)";
      };

      secure-ssl = mkOption {
        type = nullOr bool;
        default = null;
        description = mdDoc "Abort update if HTTPS certificate validation fails (default is true)";
      };

      broken-rtc = mkOption {
        type = nullOr bool;
        default = null;
        description = mdDoc "Proceed update even if certificate has expired (default is false)";
      };

      ca-trust-file = mkOption {
        type = nullOr path;
        default = null;
        description = mdDoc "Override built-in paths with path to CA certificates";
      };

      user-agent = mkOption {
        type = nullOr str;
        default = null;
        example = "Mozilla/4.0";
        description = mdDoc "Specify the User-Agent string";
      };

      providers = mkOption {
        default = {};
        type = with types; attrsOf (submodule (
          { name, config, options, ... }:
          { 
            options = {

              enable = mkOption {
                type = bool;
                default = true;
                description = mdDoc "Disable to exclude from config";
              };

              custom = mkOption {
                type = nullOr bool;
                default = false;
                description = mdDoc "Don't use a predfined provider";
              };

              provider = mkOption {
                type = str;
                default = name;
                description = mdDoc "Will be <name> by default";
              };

              ssl = mkOption {
                type = nullOr bool;
                default = null;
                description = mdDoc "Enable SSL (default is true)";
              };

              username = mkOption {
                type = str;
                description = mdDoc "Username at the provider";
                example = "alice";
              };

              passwordFile = mkOption {
                type = path;
                description = mdDoc "A file containing the passord declaration";
                example = "/run/freedns.pw";
              };

              iface = mkOption {
                type = nullOr str;
                default = null;
                example = "enp3s0";
                description = mdDoc "Use network interface as source of IP address";
              };

              checkip-server = mkOption {
                type = nullOr str;
                default = null;
                description = mdDoc "Which service to use to check ip";
              };

              checkip-path = mkOption {
                type = nullOr str;
                default = null;
                description = mdDoc "Path to append if checkip-server is provided";
              };

              checkip-ssl = mkOption {
                type = nullOr bool;
                default = null;
                description = mdDoc "Override ssl settings for this provider";
              };

              checkip-command = mkOption {
                type = nullOr str;
                default = null;
                description = mdDoc "Shell command for IP address update checking";
                example = mdDoc "`\${iproute2}/bin/ip address show enp3s0 | grep inet`";
              };

              hostname = mkOption {
                type = str;
                description = mdDoc "Domain(s) that should point to your IP";
                example = "{ myhost.ddns.net, myotherhost.ddns.net }";
              };

              user-agent = mkOption {
                type = nullOr str;
                default = null;
                example = "Mozilla/4.0";
                description = mdDoc "Override the User-Agent string";
              };

              wildcard = mkOption {
                type = nullOr bool;
                default = null;
                description = mdDoc "Enable domain name wildcarding of domain name, disabled by default";
              };

              ttl = mkOption {
                type = nullOr int;
                default = null;
                description = mdDoc "Time to live for domain name";
              };

              proxied = mkOption {
                type = nullOr bool;
                default = null;
                description = mdDoc "Proxy DNS origin via provider's CDN network";
              };

              ddns-server = mkOption {
                type = nullOr str;
                default = null;
                example = "update.example.com";
                description = mdDoc "DDNS server name, not the full URL";
              };

              ddns-path = mkOption {
                type = nullOr str;
                default = null;
                example = "/update?domain=";
                description = mdDoc "DDNS server path, by default the hostname is appended to the path";
              };

              append-myip = mkOption {
                type = nullOr bool;
                default = null;
                description = mdDoc "Append current IP to the DDNS server update path";
              };

            };
          }
        ));
      };

    };
  };

  config = with builtins; let
    boolOption = o: s: lib.optionalString (getAttr o s != null) "${o}=${if (getAttr o s) then "true" else "false"}";
    strOption = o: s: lib.optionalString (getAttr o s != null) "${o}=${getAttr o s}";
    intOption = o: s: lib.optionalString (getAttr o s != null) "${o}=${toString (getAttr o s)}";
    commandOption = o: s: lib.optionalString (getAttr o s != null) "${o}=\"${toString (getAttr o s)}\"";

    providersConf = map (p: ''
      ${if p.custom then "custom" else "provider"} ${p.provider} {
          include("${p.passwordFile}")
          ${boolOption "ssl" p}
          ${strOption "username" p}
          ${strOption "iface" p}
          ${strOption "checkip-server" p}
          ${strOption "checkip-path" p}
          ${boolOption "checkip-ssl" p}
          ${commandOption "checkip-command" p}
          ${strOption "hostname" p}
          ${strOption "user-agent" p}
          ${boolOption "wildcard" p}
          ${intOption "ttl" p}
          ${boolOption "proxied" p}
      }
      '') (filter (p: p.enable) (attrValues cfg.providers));

    configFile = ''
      ${boolOption "verify-address" cfg}
      ${boolOption "fake-address" cfg}
      ${boolOption "allow-ipv6" cfg}
      ${strOption "iface" cfg}
      ${intOption "period" cfg}
      ${intOption "forced-update" cfg}
      ${boolOption "secure-ssl" cfg}
      ${boolOption "broken-rtc" cfg}
      ${strOption "ca-trust-file" cfg}
      ${strOption "user-agent" cfg}

      ${lib.concatStrings providersConf}
      '';

  in mkIf cfg.enable {
    environment.systemPackages = [ pkgs.inadyn ];
    environment.etc."inadyn.conf".text = configFile;

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
