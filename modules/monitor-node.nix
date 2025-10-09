{ config, ... }:

{
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
              "helsinki.km:${toString node.port}"
              "stationary.km:${toString node.port}"
              "lenovo.km:${toString node.port}"
            ];
          }
        ];
      }
    ];
  };
}
