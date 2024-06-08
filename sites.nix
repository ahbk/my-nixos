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
    ssl = true;
    ports = [
      2000
      2001
    ];
  };

  "chatddx.com" = {
    enable = true;
    ssl = true;
    ports = [
      2002
      2003
    ];
  };
}
