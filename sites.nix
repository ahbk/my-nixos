{ inputs, system }:

{
  wordpress.sites."test.esse.nu" = {
    enable = true;
    ssl = true;
    basicAuth = {
      "test" = "test";
    };
  };

  wordpress.sites."esse.nu" = {
    enable = true;
    ssl = true;
    www = true;
  };

  sverigesval = {
    enable = true;
    ssl = true;
    hostname = "sverigesval.org";
    pkgs = {
      inherit (inputs.sverigesval.packages.${system}) svelte fastapi;
    };
    ports = [
      2000
      2001
    ];
  };

  chatddx = {
    enable = true;
    ssl = true;
    hostname = "chatddx.com";
    pkgs = {
      inherit (inputs.chatddx.packages.${system}) svelte django;
    };
    ports = [
      2002
      2003
    ];
  };
}
