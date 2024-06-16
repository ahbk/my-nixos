{
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

  frans = {
    enable = true;
    uid = 1000;
    name = "Mr. Admin";
    email = "frans@ahbk.se";
    aliases = [
      "postmaster@ahbk.se"
      "abuse@ahbk.se"
      "admin@ahbk.se"
    ];
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
  };

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    email = "alex@ahbk.se";
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
  };

  rolf = {
    enable = true;
    uid = 1100;
    name = "Rolf Norgberg";
    email = "rolf@sverigesval.org";
  };
}
