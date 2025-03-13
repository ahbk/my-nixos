{
  "esse_test" = {
    appname = "esse_test";
    hostname = "test.esse.nu";
    enable = true;
    ssl = true;
    basicAuth = {
      "test" = "test";
    };
  };

  "esse" = {
    appname = "esse";
    hostname = "esse.nu";
    enable = true;
    ssl = true;
    www = true;
  };

  "sverigesval" = {
    enable = true;
    hostname = "sverigesval.org";
    appname = "sverigesval";
    ssl = true;
    ports = [
      2000
      2001
    ];
  };

  "chatddx" = {
    enable = true;
    hostname = "chatddx.com";
    appname = "chatddx";
    ssl = true;
    ports = [
      2002
      2003
    ];
  };

  "sysctl-user-portal" = {
    enable = true;
    hostname = "sysctl-user-portal.curetheweb.se";
    appname = "sysctl-user-portal";
    ssl = true;
    ports = [
      2004
      2005
    ];
  };
}
