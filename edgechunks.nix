# A library of ahbk.* configuration snippets that are
# 1. Too compartmentalized to be duplicated in host configs
# 2. Not general enough to be their own modules.

{ inputs
, system
}:

{
  hosts = {
    stationary = {
      key = "AiqJQGkt5f+jc70apQs3wcidw5QSXmzln2OzijpOUzY=";
      address = "10.0.0.1";
    };
    laptop = {
      key = "lmckXsECjZUgmWclkXUU4wvb5Vh30XNGxC68ChEs+j8=";
      address = "10.0.0.2";
    };
    phone = {
      key = "YOYtjFRc71iStHnN2lV3WoiOA743ljfYep6IyVJGUWg=";
      address = "10.0.0.4";
    };
  };

  testuser = {
    enable = true;
    uid = 1337;
    name = "test";
    email = "test@example.com";
    groups = [ "wheel" ];
    keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
  };

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    email = "alex@ahbk.se";
    groups = [ "wheel" ];
    keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
  };

  frans = {
    enable = true;
    uid = 1000;
    name = "Alexander Holmbäck";
    email = "alexander.holmback@gmail.com";
    groups = [ "wheel" ];
    keys = [ (builtins.readFile ./keys/me_ed25519_key.pub) ];
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
