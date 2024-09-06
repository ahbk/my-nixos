{
  "test.esse.nu" = {
    enable = true;
    ssl = true;
    basicAuth = {
      "test" = "test";
    };
  };

  "esse.nu" = {
    enable = true;
    ssl = true;
    www = true;
  };

  "sverigesval.org" = {
    enable = true;
    user = "sverigesval.org";
    ssl = true;
    ports = [
      2000
      2001
    ];
  };

  "chatddx.com" = {
    enable = true;
    user = "chatddx.com";
    ssl = true;
    ports = [
      2002
      2003
    ];
  };

  "sysctl-user-portal.curetheweb.se" = {
    enable = true;
    user = "sysctl-user-portal";
    ssl = true;
    ports = [
      2004
      2005
    ];
  };
}
