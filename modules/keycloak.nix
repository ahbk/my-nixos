{ config, ... }:
{
  services.nginx.virtualHosts."keycloak.kompismoln.se" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://localhost:${toString config.services.keycloak.settings.http-port}";
    };
  };
  services.keycloak = {
    enable = false;
    settings = {
      hostname = "keycloak.kompismoln.se";
      http-port = 38080;
      http-host = "127.0.0.1";
      http-enabled = true;
      proxy-headers = "xforwarded";
    };
    database.passwordFile = config.age.secrets."keycloak".path;
    initialAdminPassword = "password";
  };
  age.secrets."keycloak" = {
    file = ../secrets/keycloak-root.age;
    owner = "keycloak";
    group = "keycloak";
  };
  users.users.keycloak = {
    uid = 969;
    isSystemUser = true;
    group = "keycloak";
  };
  users.groups.keycloak.gid = 969;
}
