# chunks of configuration that are commonly used
{ inputs, system }: {
  user.test = {
    enable = true;
    uid = 1337;
    name = "test";
    email = "test@example.com";
    groups = [ "wheel" ];
    keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
  };

  ide.test = {
    enable = true;
    postgresql = true;
  };

  shell.test.enable = true;

  user.frans = {
    enable = true;
    uid = 1000;
    name = "Alexander Holmbäck";
    email = "alexander.holmback@gmail.com";
    groups = [ "wheel" ];
    keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
  };

  ide.frans = {
    enable = true;
    postgresql = true;
    mysql = true;
  };

  shell.frans.enable = true;
  de.frans.enable = true;

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
    pkgs = { inherit (inputs.sverigesval.packages.${system}) svelte fastapi; };
    ports = [ 2000 2001 ];
  };

  chatddx = {
    enable = true;
    ssl = true;
    hostname = "chatddx.com";
    pkgs = { inherit (inputs.chatddx.packages.${system}) svelte django; };
    ports = [ 2002 2003 ];
  };

}
