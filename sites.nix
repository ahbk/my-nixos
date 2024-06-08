{ inputs, system }:

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
    pkgs = {
      inherit (inputs.sverigesval.packages.${system}) svelte fastapi;
    };
    ports = [
      2000
      2001
    ];
  };

  "chatddx.com" = {
    enable = true;
    ssl = true;
    pkgs = {
      inherit (inputs.chatddx.packages.${system}) svelte django;
    };
    ports = [
      2002
      2003
    ];
  };
}
