{
  config,
  lib,
  pkgs,
  inputs,
  host,
  ...
}:

let
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrsToList
    mapAttrs'
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    types
    ;

  cfg = config.my-nixos.nextcloud-rolf;
  eachSite = filterAttrs (name: cfg: cfg.enable) cfg.sites;

  lib' = (import ../lib.nix) { inherit lib pkgs; };

  siteOpts =
    { name, ... }:
    {
      config.appname = mkDefault name;
      config.username = mkDefault config.appname;
      options = {
        enable = mkEnableOption "nextcloud-rolf on this host.";
        ssl = mkOption {
          description = "Enable HTTPS";
          type = types.bool;
        };
        subnet = mkOption {
          description = "Use self-signed certificates";
          type = types.bool;
        };
        port = mkOption {
          description = "Port to serve on";
          type = types.port;
        };
        hostname = mkOption {
          description = "Namespace identifying the service externally on the network.";
          type = types.str;
        };
        appname = mkOption {
          description = "Namespace identifying the app on the system (logging, database, paths etc.)";
          type = types.str;
        };
        username = mkOption {
          description = "Owner of the app";
          type = types.str;
        };
        siteRoot = mkOption {
          description = "Path to serve";
          type = types.str;
        };
        sourceRoot = mkOption {
          description = "Where build files are gathered at runtime";
          type = types.str;
        };
      };
    };
in
{
  options = {
    my-nixos.nextcloud-rolf = {
      sites = mkOption {
        type = types.attrsOf (types.submodule siteOpts);
        default = { };
        description = "Specification of one or more nextcloud-rolf sites to serve";
      };
    };
  };

  config =
    let
      sync-commands = mapAttrs (
        name: cfg:
        pkgs.runCommand cfg.appname
          {
            src = inputs.${cfg.appname}.packages.${host.system}.default;
            nativeBuildInputs = with pkgs; [ makeWrapper ];
          }
          ''
            mkdir -p $out/bin

            makeWrapper \
              $src/bin/${cfg.appname} \
              $out/bin/${cfg.appname} \
                --append-flags ${cfg.sourceRoot} \
                --append-flags ${cfg.sourceRoot}/_src \
                --append-flags ${cfg.siteRoot} \
                --append-flags --watch
          ''
      ) eachSite;
    in
    mkIf (eachSite != { }) {

      environment.systemPackages = mapAttrsToList (name: pkg: pkg) sync-commands;
      services.nginx.virtualHosts = mapAttrs' (
        name: cfg:
        nameValuePair cfg.hostname {
          forceSSL = cfg.ssl;
          sslCertificate = mkIf cfg.subnet config.age.secrets.ahbk-cert.path;
          sslCertificateKey = mkIf cfg.subnet config.age.secrets.ahbk-cert-key.path;
          enableACME = !cfg.subnet;

          root = cfg.siteRoot;
          locations."/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ /404.html";
          };

        }
      ) eachSite;

      systemd.timers = mapAttrs' (
        name: cfg:
        nameValuePair "${cfg.appname}-build" {
          description = "Scheduled building of todays articles";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "01:00";
            Unit = "${cfg.appname}-build";
          };
        }
      ) eachSite;

      systemd.services = lib'.mergeAttrs (name: cfg: {
        "${cfg.appname}-build" = {
          description = "run ${cfg.appname}-build";
          serviceConfig = {
            Type = "oneshot";
            ExecStart =
              let
                inherit (inputs.${cfg.appname}.packages.${host.system}) gems;
              in
              "${gems}/bin/jekyll build -s ${cfg.sourceRoot}/_src -d ${cfg.siteRoot} --disable-disk-cache";
            WorkingDirectory = "${cfg.sourceRoot}/_src";
            User = cfg.username;
            Group = cfg.username;
          };
        };
        ${cfg.appname} = {
          description = "run ${cfg.appname}";
          serviceConfig = {
            ExecStart = "${sync-commands.${cfg.appname}}/bin/${cfg.appname}";
            WorkingDirectory = cfg.sourceRoot;
            User = cfg.username;
            Group = cfg.username;
          };
          wantedBy = [ "multi-user.target" ];
        };
      }) eachSite;
    };
}
