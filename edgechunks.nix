# A library of ahbk.* configuration snippets that are
# 1. Too compartmentalized to be duplicated in host configs
# 2. Not general enough to be their own modules.

{ inputs
, system
, lib
}:

{
  hosts = import ./hosts.nix;
  testuser = {
    enable = true;
    uid = 1337;
    name = "test";
    email = "test@example.com";
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-test.pub ];
  };

  backup = {
    enable = true;
    uid = 2001;
    name = "Mr. Backup";
    keys = [
      ./keys/ssh-user-backup.pub
      ./keys/ssh-user-alex.pub
    ];
  };

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    email = "alex@ahbk.se";
    groups = [ "wheel" ];
    keys = [
      ./keys/ssh-user-alex.pub
    ];
  };

  frans = {
    enable = true;
    uid = 1000;
    name = "Alexander Holmbäck";
    email = "alexander.holmback@gmail.com";
    groups = [ "wheel" ];
    keys = [
      ./keys/ssh-user-alex.pub
    ];
  };

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
