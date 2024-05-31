{ host
, ...
}:

{
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = host.stateVersion;
  networking.hostName = host.name;
}
