{
  admin = {
    enable = true;
    uid = 1000;
    name = "Administrator";
    groups = [ "wheel" ];
    keys = [ ./public-keys/user-admin-ssh-key.pub ];
    email = "admin@kompismoln.se";
  };

  alex = {
    enable = true;
    name = "Alexander Holmbäck";
    uid = 1001;
    groups = [
      "wheel"
      "nginx"
    ];
    keys = [ ./public-keys/user-alex-ssh-key.pub ];
    email = "alex@kompismoln.se";
    aliases = [
      "dmarc-reports@ahbk.se"
      "postmaster@ahbk.se"
      "abuse@ahbk.se"
      "info@ahbk.se"
      "hej@kompismoln.se"
      "alex@kompismoln.se"
      "no-reply@klimatkalendern.nu"
      "admin@kompismoln.se"
    ];
  };

  johanna = {
    enable = true;
    groups = [ "nextcloud-kompismoln" ];
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
  };

  ami = {
    enable = true;
    groups = [ ];
    uid = 1104;
    name = "ami";
    email = "gunami59@gmail.com";
  };
}
