let
  # strip last row break
  key = name: builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ../keys/ssh-${name}.pub);

  # keys
  alex = key "user-alex";
  glesys = key "host-glesys";
  laptop = key "host-laptop";
  stationary = key "host-stationary";

  all = [
    alex
    glesys
    laptop
    stationary
  ];
in
{
  "ahbk-cert-key.age".publicKeys = all;
  "ahbk-cert.age".publicKeys = all;

  "linux-passwd-hashed-alex.age".publicKeys = all;
  "linux-passwd-hashed-backup.age".publicKeys = all;
  "linux-passwd-hashed-frans.age".publicKeys = all;
  "linux-passwd-hashed-olof.age".publicKeys = all;
  "linux-passwd-hashed-rolf.age".publicKeys = all;

  "linux-passwd-plain-alex.age".publicKeys = all;
  "linux-passwd-plain-backup.age".publicKeys = all;
  "linux-passwd-plain-frans.age".publicKeys = all;
  "linux-passwd-plain-olof.age".publicKeys = all;
  "linux-passwd-plain-rolf.age".publicKeys = all;

  "nextcloud-pass.age".publicKeys = all;

  "mail-hashed-alex.age".publicKeys = all;
  "mail-hashed-frans.age".publicKeys = all;
  "mail-hashed-olof.age".publicKeys = all;
  "mail-hashed-rolf.age".publicKeys = all;

  "mail-plain-alex.age".publicKeys = all;
  "mail-plain-frans.age".publicKeys = all;
  "mail-plain-olof.age".publicKeys = all;
  "mail-plain-rolf.age".publicKeys = all;

  "webapp-key-dev.chatddx.com.age".publicKeys = all;
  "webapp-key-chatddx.com.age".publicKeys = all;
  "webapp-key-dev.sverigesval.org.age".publicKeys = all;
  "webapp-key-sverigesval.org.age".publicKeys = all;
  "webapp-key-sysctl-user-portal.curetheweb.se.age".publicKeys = all;

  "wg-key-laptop.age".publicKeys = [
    alex
    laptop
  ];

  "wg-key-stationary.age".publicKeys = [
    alex
    stationary
  ];

  "wg-key-glesys.age".publicKeys = [
    alex
    glesys
  ];

  "api-key-glesys.age".publicKeys = [
    alex
    stationary
  ];
}
