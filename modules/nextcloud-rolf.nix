{
  config,
  lib,
  lib',
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

  serverName = cfg: if cfg.www == "yes" then "www.${cfg.hostname}" else cfg.hostname;
  serverNameRedirect = cfg: if cfg.www == "yes" then cfg.hostname else "www.${cfg.hostname}";

  siteOpts =
    { name, ... }:
    {
      config.appname = mkDefault name;
      config.username = mkDefault config.appname;
      options = {
        enable = mkEnableOption "nextcloud-rolf on this host.";
        ssl = mkOption {
          description = "Enable HTTPS";
          default = true;
          type = types.bool;
        };
        subnet = mkOption {
          description = "Use self-signed certificates";
          default = false;
          type = types.bool;
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
        www = mkOption {
          description = "Prefix the url with www.";
          default = "no";
          type = types.enum [
            "no"
            "yes"
            "redirect"
          ];
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

      security.acme.certs = lib.mapAttrs' (name: cfg: {
        name = serverName cfg;
        value = mkIf (cfg.ssl && !cfg.subnet) {
          extraDomainNames = [ (serverNameRedirect cfg) ];
        };
      }) eachSite;

      services.nginx.virtualHosts = lib'.mergeAttrs (name: cfg: {
        ${serverNameRedirect cfg} = {
          forceSSL = cfg.ssl;
          sslCertificate = mkIf cfg.subnet ../public-keys/domain-km-tls-cert.pem;
          sslCertificateKey = mkIf cfg.subnet config.sops.secrets."km/tls-cert".path;
          useACMEHost = mkIf (cfg.ssl && !cfg.subnet) (serverName cfg);
          extraConfig = ''
            return 301 $scheme://${serverName cfg}$request_uri;
          '';
        };

        ${serverName cfg} = {
          forceSSL = cfg.ssl;
          sslCertificate = mkIf cfg.subnet ../public-keys/domain-km-tls-cert.pem;
          sslCertificateKey = mkIf cfg.subnet config.sops.secrets."km/tls-cert".path;
          enableACME = cfg.ssl && !cfg.subnet;

          root = cfg.siteRoot;
          locations."/" = {
            index = "index.html";
            tryFiles = "$uri $uri/ /404.html";
          };
        };
      }) eachSite;

      systemd.timers = mapAttrs' (
        name: cfg:
        nameValuePair "${cfg.appname}-build" {
          description = "Scheduled building of todays articles";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "01:00";
            Unit = "${cfg.appname}-build.service";
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
