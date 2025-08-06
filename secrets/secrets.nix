let
  # strip last row break
  key = name: builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ../keys/ssh-${name}.pub);

  # keys
  alex = key "user-alex";
  ludvig = key "user-ludvig";
  glesys = key "host-glesys";
  helsinki = key "host-helsinki";
  laptop = key "host-laptop";
  stationary = key "host-stationary";
  friday = key "host-friday";
  lenovo = key "host-lenovo";

  all = [
    alex
    glesys
    helsinki
    laptop
    stationary
    lenovo
    friday
  ];

  mail-host = glesys;
  admin = alex;
in
{
  "ssh-host-helsinki.age".publicKeys = [ admin ];

  # These play no role in security and can be accessed by all
  "ahbk-cert-key.age".publicKeys = all;
  "ahbk-cert.age".publicKeys = all;

  # Every host needs admin or they will be inaccessible
  "linux-passwd-hashed-admin.age".publicKeys = all;
  "linux-passwd-plain-admin.age".publicKeys = all;
  "mail-hashed-admin.age".publicKeys = [
    admin
    mail-host
  ];
  "mail-plain-admin.age".publicKeys = all;

  "linux-passwd-hashed-alex.age".publicKeys = all;
  "linux-passwd-plain-alex.age".publicKeys = all;
  "mail-hashed-alex.age".publicKeys = [
    admin
    mail-host
  ];
  "mail-plain-alex.age".publicKeys = all;

  "linux-passwd-hashed-johanna.age".publicKeys = [
    admin
    friday
  ];

  "linux-passwd-plain-johanna.age".publicKeys = [
    admin
    friday
  ];

  "linux-passwd-hashed-backup.age".publicKeys = all;
  "linux-passwd-plain-backup.age".publicKeys = all;

  "linux-passwd-hashed-ludvig.age".publicKeys = [
    admin
    ludvig
    glesys
  ];

  "linux-passwd-plain-ludvig.age".publicKeys = [
    admin
    ludvig
    glesys
  ];

  "nextcloud-kompismoln-root.age".publicKeys = [
    admin
    glesys
  ];

  "nextcloud-ahbk-root.age".publicKeys = [
    admin
    glesys
  ];

  "keycloak-root.age".publicKeys = [
    admin
    glesys
  ];

  "klimatkalendern1-mobilizon.age".publicKeys = [
    admin
    ludvig
    glesys
    stationary
  ];

  "webapp-key-chatddx.age".publicKeys = all;
  "webapp-key-sysctl-user-portal.age".publicKeys = all;

  "wg-key-laptop.age".publicKeys = [
    admin
    laptop
  ];

  "wg-key-stationary.age".publicKeys = [
    admin
    stationary
  ];

  "wg-key-helsinki.age".publicKeys = [
    admin
    helsinki
  ];

  "wg-key-glesys.age".publicKeys = [
    admin
    glesys
  ];

  "wg-key-friday.age".publicKeys = [
    admin
    friday
  ];

  "wg-key-lenovo.age".publicKeys = [
    admin
    lenovo
  ];

  "api-key-glesys.age".publicKeys = [
    admin
    stationary
  ];

}
