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

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    email = "alex@ahbk.se";
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
  };

  frans = {
    enable = true;
    uid = 1000;
    name = "Alexander Holmbäck";
    email = "alexander.holmback@gmail.com";
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
  };
}
