let
  # strip last row break
  key = name: builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ../keys/ssh-${name}.pub);

  # keys
  laptop = key "host-laptop";
  stationary = key "host-stationary";
  glesys = key "host-glesys";
  container = key "host-container";
  test = key "user-test";
  alex = key "user-alex";

  all = [
    alex
    stationary
    glesys
    laptop
    container
  ];
  all-test = all ++ [ test ];
in
{
  "linux-passwd-hashed-test.age".publicKeys = all-test;
  "linux-passwd-hashed-frans.age".publicKeys = all;
  "linux-passwd-hashed-alex.age".publicKeys = all;
  "linux-passwd-hashed-backup.age".publicKeys = all;

  "linux-passwd-plain-test.age".publicKeys = all-test;
  "linux-passwd-plain-frans.age".publicKeys = all;
  "linux-passwd-plain-alex.age".publicKeys = all;
  "linux-passwd-plain-backup.age".publicKeys = all;

  "webapp-key-dev.chatddx.com.age".publicKeys = all;
  "webapp-key-chatddx.com.age".publicKeys = all;
  "webapp-key-dev.sverigesval.org.age".publicKeys = all;
  "webapp-key-sverigesval.org.age".publicKeys = all;

  "wg-key-laptop.age".publicKeys = [
    laptop
    alex
  ];
  "wg-key-stationary.age".publicKeys = [
    stationary
    alex
  ];
  "wg-key-glesys.age".publicKeys = [
    glesys
    alex
  ];

  "api-key-glesys.age".publicKeys = all;
}
