let
  # strip last row break
  readKey = f: builtins.replaceStrings ["\n"] [""] (builtins.readFile f);

  # keys
  laptop = "${(readKey ../keys/laptop_ed25519_key.pub)}";
  stationary = "${(readKey ../keys/stationary_ed25519_key.pub)}";
  glesys = "${(readKey ../keys/glesys_ed25519_key.pub)}";
  test = "${(readKey ../keys/test_ed25519_key.pub)}";
  me = "${(readKey ../keys/me_ed25519_key.pub)}";
  all = [ me stationary glesys test laptop ];
in {
  "ddns-password.age".publicKeys = all;
  "test-pw.age".publicKeys = all;
  "frans-pw.age".publicKeys = all;
  "alex-pw.age".publicKeys = all;
  "dev.chatddx.com-secret-key.age".publicKeys = all;
  "chatddx.com-secret-key.age".publicKeys = all;
  "dev.sverigesval.org-secret-key.age".publicKeys = all;
  "sverigesval.org-secret-key.age".publicKeys = all;
}
