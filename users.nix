{
  admin = {
    enable = true;
    uid = 1000;
    name = "Administrator";
    groups = [ "wheel" ];
    keys = [ ./keys/ssh-user-alex.pub ];
    email = "admin@ahbk.se";
  };

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    groups = [
      "wheel"
      "nginx"
    ];
    keys = [ ./keys/ssh-user-alex.pub ];
    email = "alex@ahbk.se";
    aliases = [
      "dmarc-reports@ahbk.se"
      "postmaster@ahbk.se"
      "abuse@ahbk.se"
      "info@ahbk.se"
      "alex@sverigesval.org"
      "hej@kompismoln.se"
      "alex@kompismoln.se"
      "klimatkalendern@kompismoln.se"
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

  johanna = {
    enable = true;
    uid = 1102;
    name = "Johanna Landberg";
    email = "landberg@gmail.com";
  };

  ludvig = {
    enable = true;
    groups = [ "mobilizon" ];
    uid = 1103;
    name = "ludvig";
    email = "ludvig.janiuk@proton.me";
    keys = [ ./keys/ssh-user-ludvig.pub ];
  };
}
