let
  jarvis = "${(builtins.readFile ../keys/jarvis_ed25519_key.pub)}";
  friday = "${(builtins.readFile ../keys/friday_ed25519_key.pub)}";
  test = "${(builtins.readFile ../keys/test_ed25519_key.pub)}";
  me = "${(builtins.readFile ../keys/me_ed25519_key.pub)}";
in {
  "ddns-password.age".publicKeys = [me friday jarvis];
  "rolf_secret_key.age".publicKeys = [me friday jarvis];
  "chatddx_secret_key.age".publicKeys = [me friday jarvis];
  "test-pw.age".publicKeys = [me test friday];
  "frans-pw.age".publicKeys = [ me test friday ];
}
