{
  "esse_test" = {
    enable = true;
    appname = "esse_test";
    hostname = "test.esse.nu";
    www = "yes";
    basicAuth = {
      "test" = "test";
    };
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
