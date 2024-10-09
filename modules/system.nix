{ config, host, ... }:

{
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = host.stateVersion;
  networking.hostName = host.name;

  services.prometheus = {
    exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = with config.services.prometheus.exporters; [
          {
            targets = [
              "glesys.ahbk:${toString node.port}"
              "stationary.ahbk:${toString node.port}"
              "laptop.ahbk:${toString node.port}"
            ];
          }
        ];
      }
    ];
  };
}
