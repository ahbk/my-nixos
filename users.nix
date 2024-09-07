{
  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
    email = "alex@ahbk.se";
    aliases = [
      "postmaster@ahbk.se"
      "abuse@ahbk.se"
      "info@ahbk.se"
    ];
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
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
    email = "frans@ahbk.se";
    aliases = [ "admin@ahbk.se" ];
  };

  olof = {
    enable = true;
    uid = 1100;
    name = "Olof Silfver";
    email = "olof@chatddx.com";
    aliases = [
      "postmaster@chatddx.com"
      "abuse@chatddx.com"
      "info@chatddx.com"
    ];
  };

  rolf = {
    enable = true;
    uid = 1101;
    name = "Rolf Norgberg";
    email = "rolf@sverigesval.org";
    aliases = [
      "postmaster@sverigesval.org"
      "abuse@sverigesval.org"
      "info@sverigesva.org"
    ];
  };
}
