{
  "alex@debian" = {
    name = "alex@debian";
    system = "x86_64-linux";
    stateVersion = "23.11";
    my-nixos-hm = {
      ide = {
        enable = true;
        name = "Alexander Holmbäck";
        email = "alex@ahbk.se";
      };
      shell.enable = true;
      user = {
        enable = true;
        name = "alex";
      };
    };
  };
  "alex@arch" = {
    name = "alex@arch";
    system = "x86_64-linux";
    stateVersion = "24.05";
    my-nixos-hm = {
      ide = {
        enable = true;
        name = "Alexander Holmbäck";
        email = "alex@ahbk.se";
      };
      shell.enable = true;
      user = {
        enable = true;
        name = "alex";
      };
    };
  };
}
