let
  me = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETPlH6kPI0KOv0jeOey+iwf8p/hhlIXHd9gIFAt6zMG alexander.holmback@gmail.com";
  friday = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDg+gZVrof/UixfxjOjQt+5OOAtZj6SKPZv1YXqtGWs root@friday";
  jarvis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzC6OKR5RpAMADxKsDlTrlE/4nrqSOLFK2MmcwHo+3E root@jarvis";
in {
  "ddns-password.age".publicKeys = [me friday jarvis];
  "rolf_secret_key.age".publicKeys = [me friday jarvis];
  "chatddx_secret_key.age".publicKeys = [me friday jarvis];
}
