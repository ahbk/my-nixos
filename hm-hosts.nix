{
  "frans@debian" = {
    system = "x86_64-linux";
    my-nixos-hm = {
      ide = {
        enable = true;
        name = "Alexander Holmbäck";
        email = "alexander.holmback@gmail.com";
      };
      shell.enable = true;
      user = {
        enable = true;
        name = "frans";
      };
    };
  };
}
