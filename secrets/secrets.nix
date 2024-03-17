let
  laptop = "${(builtins.readFile ../keys/laptop_ed25519_key.pub)}";
  stationary = "${(builtins.readFile ../keys/stationary_ed25519_key.pub)}";
  glesys = "${(builtins.readFile ../keys/glesys_ed25519_key.pub)}";
  test = "${(builtins.readFile ../keys/test_ed25519_key.pub)}";
  me = "${(builtins.readFile ../keys/me_ed25519_key.pub)}";
  all = [ me stationary glesys test laptop ];
in {
  "ddns-password.age".publicKeys = all;
  "test-pw.age".publicKeys = all;
  "frans-pw.age".publicKeys = all;
  "dev.chatddx.com-secret-key.age".publicKeys = all;
  "chatddx.com-secret-key.age".publicKeys = all;
  "dev.sverigesval.org-secret-key.age".publicKeys = all;
  "sverigesval.org-secret-key.age".publicKeys = all;
}
