let
  # strip last row break
  readKey = f: builtins.replaceStrings ["\n"] [""] (builtins.readFile f);

  # keys
  laptop = "${(readKey ../keys/laptop_ed25519_key.pub)}";
  stationary = "${(readKey ../keys/stationary_ed25519_key.pub)}";
  glesys = "${(readKey ../keys/glesys_ed25519_key.pub)}";
  test = "${(readKey ../keys/test_ed25519_key.pub)}";
  me = "${(readKey ../keys/me_ed25519_key.pub)}";

  all = [ me stationary glesys laptop ];
  all-test = all ++ [ test ];

in {
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

  "wg-key-laptop.age".publicKeys = [ laptop me ];
  "wg-key-stationary.age".publicKeys = [ stationary me ];
  "wg-key-glesys.age".publicKeys = [ glesys me ];

  "api-key-glesys.age".publicKeys = all;
}
