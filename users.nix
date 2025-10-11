{
  admin = {
    enable = true;
    uid = 1000;
    name = "Administrator";
    groups = [ "wheel" ];
    keys = [ ./public-keys/user-admin-ssh-key.pub ];
    email = "admin@kompismoln.se";
    aliases = [
      "postmaster@kompismoln.se"
    ];
  };

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    groups = [ "wheel" ];
    keys = [ ./public-keys/user-alex-ssh-key.pub ];
    email = "alex@kompismoln.se";
    aliases = [
      "alex@ahbk.se"
      "alex@klimatkalendern.nu"
    ];
  };

  johanna = {
    enable = true;
    name = "Johanna Landberg";
    groups = [ ];
    uid = 1102;
    email = "landberg@gmail.com";
  };

  ludvig = {
    enable = true;
    name = "ludvig";
    groups = [ ];
    uid = 1103;
    email = "ludvig.janiuk@proton.me";
  };

  ami = {
    enable = true;
    name = "ami";
    groups = [ ];
    uid = 1104;
    email = "gunami59@gmail.com";
  };
}
